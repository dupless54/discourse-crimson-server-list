# frozen_string_literal: true

module ::CrimsonServerList
  class ServersController < ::ApplicationController
    requires_plugin CrimsonServerList::PLUGIN_NAME

    before_action :ensure_plugin_enabled
    before_action :ensure_logged_in,
                  only: %i[create update_owned vote refresh upsert_review destroy_review]
    before_action :ensure_admin_user, only: %i[update]

    def index
      public_scope = CrimsonServerList::Server.publicly_visible
      game_counts = public_scope.group(:game_slug).count
      servers = filtered_scope(public_scope)
      voted_ids = voted_server_ids(servers)

      payload = {
        games:
          CrimsonServerList::GAMES.map do |game|
            game.merge(server_count: game_counts.fetch(game[:slug], 0))
          end,
        servers:
          servers.map do |server|
            serialize_server(server, voted_today: voted_ids.include?(server.id))
          end,
        stats: {
          server_count: public_scope.count,
          vote_count: public_scope.sum(:vote_count),
          online_count: public_scope.where(status: "online").count,
          game_count: game_counts.count { |_slug, count| count.positive? },
          review_count: public_scope.sum(:review_count),
        },
        viewer: viewer_payload,
      }

      if current_user&.admin?
        payload[:pending_servers] =
          CrimsonServerList::Server
            .where(approved: false, enabled: true)
            .includes(:owner)
            .order(created_at: :asc)
            .limit(100)
            .map { |server| serialize_server(server, include_private: true) }
      end

      render json: payload
    end

    def show
      server =
        CrimsonServerList::Server
          .includes(:owner)
          .find_by!(slug: params[:slug])
      unless (server.approved? && server.enabled?) || can_manage_server?(server)
        raise Discourse::NotFound
      end

      reviews =
        server
          .reviews
          .includes(:user)
          .order(updated_at: :desc)
          .limit(SiteSetting.crimson_server_list_reviews_limit.to_i.clamp(10, 200))

      render json: {
               server: serialize_server(server, voted_today: voted_server_ids([server]).include?(server.id)),
               games: CrimsonServerList::GAMES,
               reviews: reviews.map { |review| serialize_review(review) },
               viewer: viewer_payload(server: server),
             }
    end

    def create
      unless SiteSetting.crimson_server_list_submission_enabled
        return render_error(I18n.t("crimson_server_list.errors.submissions_disabled"), :forbidden)
      end

      server = CrimsonServerList::Server.new(server_params)
      server.owner = current_user
      server.status = "unknown"
      server.players_online = 0
      server.players_max = 0
      server.approved = current_user.admin? || !SiteSetting.crimson_server_list_require_approval
      normalize_server(server)

      if server.save
        enqueue_probe(server)
        render json: {
                 server: serialize_server(server, include_private: true),
                 pending: !server.approved?,
                 message:
                   I18n.t(
                     server.approved? ?
                       "crimson_server_list.messages.published" :
                       "crimson_server_list.messages.submitted",
                   ),
               },
               status: :created
      else
        render_validation_errors(server)
      end
    end

    def update_owned
      server = CrimsonServerList::Server.find(params[:id])
      return render_error(I18n.t("crimson_server_list.errors.not_owner"), :forbidden) unless can_manage_server?(server)

      server.assign_attributes(server_params)
      endpoint_changed =
        server.will_save_change_to_game_slug? || server.will_save_change_to_host? ||
          server.will_save_change_to_port? || server.will_save_change_to_query_port?
      normalize_server(server)

      if !current_user.admin? && SiteSetting.crimson_server_list_owner_edits_require_approval
        server.approved = false
      end

      reset_live_status(server) if endpoint_changed

      if server.save
        enqueue_probe(server)
        render json: {
                 server: serialize_server(server, include_private: true),
                 pending: !server.approved?,
                 message:
                   I18n.t(
                     server.approved? ?
                       "crimson_server_list.messages.updated" :
                       "crimson_server_list.messages.updated_pending",
                   ),
               }
      else
        render_validation_errors(server)
      end
    end

    def vote
      unless SiteSetting.crimson_server_list_votes_enabled
        return render_error(I18n.t("crimson_server_list.errors.votes_disabled"), :forbidden)
      end

      server = CrimsonServerList::Server.publicly_visible.find(params[:id])
      vote =
        CrimsonServerList::Vote.new(
          server: server,
          user: current_user,
          voted_on: Time.zone.today,
        )

      if vote.save
        server.reload
        render json: {
                 server_id: server.id,
                 vote_count: server.vote_count,
                 voted_today: true,
                 message: I18n.t("crimson_server_list.messages.voted"),
               }
      else
        render_error(I18n.t("crimson_server_list.errors.already_voted"), :unprocessable_entity)
      end
    rescue ActiveRecord::RecordNotUnique
      render_error(I18n.t("crimson_server_list.errors.already_voted"), :unprocessable_entity)
    end

    def refresh
      server = CrimsonServerList::Server.find(params[:id])
      return render_error(I18n.t("crimson_server_list.errors.not_owner"), :forbidden) unless can_manage_server?(server)
      unless SiteSetting.crimson_server_list_live_query_enabled && server.approved? && server.enabled? &&
               server.monitoring_enabled?
        return render_error("Bu sunucu için canlı sorgu etkin değil.", :unprocessable_entity)
      end

      throttle_key = "crimson-server-list:manual-refresh:#{current_user.id}:#{server.id}"
      unless Discourse.redis.set(throttle_key, "1", nx: true, ex: 30)
        return render_error("Canlı sorgu kısa süre önce yenilendi.", :too_many_requests)
      end

      enqueue_probe(server, force: true)
      render json: { queued: true, message: "Canlı durum sorgusu kuyruğa alındı." }
    end

    def upsert_review
      unless SiteSetting.crimson_server_list_reviews_enabled
        return render_error(I18n.t("crimson_server_list.errors.reviews_disabled"), :forbidden)
      end

      server = CrimsonServerList::Server.publicly_visible.find(params[:id])
      review = server.reviews.find_or_initialize_by(user_id: current_user.id)
      review.assign_attributes(review_params)

      if review.save
        refresh_review_stats(server)
        render json: {
                 review: serialize_review(review.reload),
                 rating: rating_payload(server.reload),
                 message: I18n.t("crimson_server_list.messages.reviewed"),
               }
      else
        render_validation_errors(review)
      end
    rescue ActiveRecord::RecordNotUnique
      review = server.reviews.find_by!(user_id: current_user.id)
      review.assign_attributes(review_params)
      if review.save
        refresh_review_stats(server)
        render json: {
                 review: serialize_review(review.reload),
                 rating: rating_payload(server.reload),
                 message: I18n.t("crimson_server_list.messages.reviewed"),
               }
      else
        render_validation_errors(review)
      end
    end

    def destroy_review
      server = CrimsonServerList::Server.publicly_visible.find(params[:id])
      review = server.reviews.find_by!(user_id: current_user.id)
      review.destroy!
      refresh_review_stats(server)

      render json: {
               deleted: true,
               rating: rating_payload(server.reload),
               message: I18n.t("crimson_server_list.messages.review_deleted"),
             }
    end

    def update
      server = CrimsonServerList::Server.find(params[:id])
      server.assign_attributes(admin_server_params)
      normalize_server(server)

      if server.save
        enqueue_probe(server)
        render json: { server: serialize_server(server, include_private: true) }
      else
        render_validation_errors(server)
      end
    end

    private

    def ensure_plugin_enabled
      raise Discourse::NotFound unless SiteSetting.crimson_server_list_enabled
    end

    def ensure_admin_user
      raise Discourse::InvalidAccess unless current_user&.admin?
    end

    def can_manage_server?(server)
      current_user.present? && (current_user.admin? || server.owner_id == current_user.id)
    end

    def viewer_payload(server: nil)
      public_server = server.nil? || (server.approved? && server.enabled?)
      {
        logged_in: current_user.present?,
        is_admin: current_user&.admin? || false,
        can_submit:
          current_user.present? && SiteSetting.crimson_server_list_submission_enabled,
        can_vote:
          current_user.present? && public_server && SiteSetting.crimson_server_list_votes_enabled,
        can_review:
          current_user.present? && public_server && SiteSetting.crimson_server_list_reviews_enabled,
        can_edit: server.present? && can_manage_server?(server),
        live_query_enabled: SiteSetting.crimson_server_list_live_query_enabled,
      }
    end

    def filtered_scope(base_scope)
      scope = base_scope.includes(:owner)

      game_slug = params[:game].to_s
      scope = scope.where(game_slug: game_slug) if CrimsonServerList::GAME_SLUGS.include?(game_slug)

      query = params[:q].to_s.strip.first(80)
      if query.present?
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
        scope =
          scope.where(
            "crimson_game_servers.name ILIKE :pattern OR " \
              "crimson_game_servers.short_description ILIKE :pattern OR " \
              "crimson_game_servers.host ILIKE :pattern",
            pattern: pattern,
          )
      end

      scope =
        case params[:sort].to_s
        when "new"
          scope.order(created_at: :desc)
        when "players"
          scope.order(players_online: :desc, vote_count: :desc, created_at: :desc)
        when "rating"
          scope.order(
            Arel.sql(
              "CASE WHEN crimson_game_servers.review_count > 0 " \
                "THEN crimson_game_servers.rating_sum::float / crimson_game_servers.review_count " \
                "ELSE 0 END DESC",
            ),
            review_count: :desc,
            vote_count: :desc,
          )
        when "online"
          scope.order(
            Arel.sql("CASE crimson_game_servers.status WHEN 'online' THEN 0 ELSE 1 END"),
            vote_count: :desc,
          )
        else
          scope.order(featured: :desc, vote_count: :desc, players_online: :desc, created_at: :desc)
        end

      maximum = SiteSetting.crimson_server_list_results_limit.to_i.clamp(10, 200)
      scope.limit(maximum).to_a
    end

    def voted_server_ids(servers)
      return Set.new if current_user.blank? || servers.blank?

      CrimsonServerList::Vote
        .where(user_id: current_user.id, voted_on: Time.zone.today, server_id: servers.map(&:id))
        .pluck(:server_id)
        .to_set
    end

    def serialize_server(server, voted_today: false, include_private: false)
      game = CrimsonServerList.game(server.game_slug)
      owner = server.owner
      cache = CrimsonServerList::ProbeService.read_cache(server.id)
      cache = cache.with_indifferent_access if cache.respond_to?(:with_indifferent_access)
      supports_player_count = cache&.fetch(:supports_player_count, nil)
      supports_player_count = %w[minecraft fivem rust ark].include?(server.game_slug) if supports_player_count.nil?
      live_status = cache&.fetch(:status, nil) || server.status

      payload = {
        id: server.id,
        slug: server.slug,
        detail_url: "/servers/#{server.slug}",
        game_slug: server.game_slug,
        game: game,
        name: server.name,
        short_description: server.short_description,
        description: server.description,
        host: server.host,
        port: server.port,
        query_port: server.query_port,
        address: display_address(server),
        website_url: server.website_url,
        discord_url: server.discord_url,
        banner_url: server.banner_url,
        country_code: server.country_code,
        language: server.language,
        version: server.version,
        mode: server.mode,
        status: live_status,
        status_label: I18n.t("crimson_server_list.statuses.#{live_status}"),
        players_online: cache&.fetch(:players_online, nil) || server.players_online,
        players_max: cache&.fetch(:players_max, nil) || server.players_max,
        supports_player_count: supports_player_count,
        query_adapter: cache&.fetch(:adapter, nil) || adapter_name(server.game_slug),
        last_checked_at: cache&.fetch(:last_checked_at, nil) || server.last_checked_at&.iso8601,
        last_response_ms: cache&.fetch(:last_response_ms, nil) || server.last_response_ms,
        monitoring_enabled: server.monitoring_enabled,
        vote_count: server.vote_count,
        featured: server.featured,
        voted_today: voted_today,
        review_count: server.review_count,
        average_rating: server.average_rating,
        can_edit: can_manage_server?(server),
        approved: server.approved,
        enabled: server.enabled,
        created_at: server.created_at&.iso8601,
        owner:
          if owner
            {
              id: owner.id,
              username: owner.username,
              name: owner.name.presence || owner.username,
              avatar_url: owner.avatar_template.to_s.gsub("{size}", "96"),
              profile_url: "/u/#{owner.username_lower}",
            }
          end,
      }

      if include_private || can_manage_server?(server)
        payload[:last_query_error] = server.last_query_error
      end

      payload
    end

    def serialize_review(review)
      user = review.user
      {
        id: review.id,
        rating: review.rating,
        body: review.body,
        created_at: review.created_at&.iso8601,
        updated_at: review.updated_at&.iso8601,
        mine: current_user&.id == review.user_id,
        user: {
          id: user.id,
          username: user.username,
          name: user.name.presence || user.username,
          avatar_url: user.avatar_template.to_s.gsub("{size}", "96"),
          profile_url: "/u/#{user.username_lower}",
        },
      }
    end

    def rating_payload(server)
      {
        average_rating: server.average_rating,
        review_count: server.review_count,
      }
    end

    def adapter_name(game_slug)
      {
        "minecraft" => "minecraft-java",
        "fivem" => "fivem-http",
        "rust" => "rust-a2s",
        "ark" => "ark-a2s",
        "silkroad-online" => "silkroad-tcp",
        "metin2" => "metin2-tcp",
        "knight-online" => "knight-online-tcp",
        "world-of-warcraft" => "wow-realm-tcp",
      }.fetch(game_slug)
    end

    def display_address(server)
      host = server.host.to_s
      host = "[#{host}]" if host.include?(":") && !host.start_with?("[")
      "#{host}:#{server.port}"
    end

    def server_params
      params.permit(
        :game_slug,
        :name,
        :short_description,
        :description,
        :host,
        :port,
        :query_port,
        :website_url,
        :discord_url,
        :banner_url,
        :country_code,
        :language,
        :version,
        :mode,
        :monitoring_enabled,
      )
    end

    def review_params
      params.permit(:rating, :body)
    end

    def admin_server_params
      params.permit(
        :approved,
        :enabled,
        :featured,
        :status,
        :players_online,
        :players_max,
        :monitoring_enabled,
      )
    end

    def normalize_server(server)
      server.host = CrimsonServerList::NetworkPolicy.normalize_host(server.host)
      server.country_code = server.country_code.to_s.strip.upcase
      server.query_port = nil if server.query_port.blank?
      %i[website_url discord_url banner_url language version mode description].each do |attribute|
        server.public_send("#{attribute}=", server.public_send(attribute).to_s.strip.presence)
      end
    end

    def reset_live_status(server)
      server.status = "unknown"
      server.players_online = 0
      server.players_max = 0
      server.last_checked_at = nil
      server.last_query_error = nil
      server.last_response_ms = nil
      Discourse.cache.delete(CrimsonServerList::ProbeService.cache_key(server.id)) if server.persisted?
    end

    def enqueue_probe(server, force: false)
      return unless SiteSetting.crimson_server_list_live_query_enabled
      return unless server.approved? && server.enabled? && server.monitoring_enabled?

      Jobs.enqueue(:crimson_server_list_probe, server_id: server.id, force: force)
    end

    def refresh_review_stats(server)
      server.with_lock do
        server.update_columns(
          review_count: server.reviews.count,
          rating_sum: server.reviews.sum(:rating),
        )
      end
    end

    def render_validation_errors(record)
      render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
    end

    def render_error(message, status)
      render json: { errors: [message] }, status: status
    end
  end
end
