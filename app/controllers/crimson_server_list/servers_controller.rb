# frozen_string_literal: true

require "digest"

module ::CrimsonServerList
  class ServersController < ::ApplicationController
    requires_plugin CrimsonServerList::PLUGIN_NAME

    before_action :ensure_plugin_enabled
    before_action :ensure_logged_in,
                  only: %i[create update_owned destroy vote refresh request_claim upsert_review destroy_review review_claim]
    before_action :ensure_staff_user, only: %i[destroy]
    before_action :ensure_admin_user, only: %i[update review_claim]

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
        payload[:pending_claims] =
          CrimsonServerList::ClaimRequest
            .where(status: "pending")
            .includes(:requester, server: :owner)
            .order(created_at: :asc)
            .limit(100)
            .map { |claim| serialize_claim(claim) }
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

      track_public_view(server)

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

    def destroy
      server = CrimsonServerList::Server.find(params[:id])
      Discourse.cache.delete(CrimsonServerList::ProbeService.cache_key(server.id))
      server.destroy!

      render json: {
               deleted: true,
               redirect_url: "/servers",
               message: I18n.t("crimson_server_list.messages.deleted"),
             }
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

    def request_claim
      server = CrimsonServerList::Server.publicly_visible.find(params[:id])
      if server.owner_id == current_user.id
        return render_error(I18n.t("crimson_server_list.errors.already_owner"), :unprocessable_entity)
      end

      claim =
        CrimsonServerList::ClaimRequest.find_or_initialize_by(
          server_id: server.id,
          requester_id: current_user.id,
        )

      if claim.persisted? && claim.status == "pending"
        return render_error(I18n.t("crimson_server_list.errors.claim_pending"), :unprocessable_entity)
      end

      claim.assign_attributes(
        status: "pending",
        note: params[:note].to_s.strip.first(500).presence,
        reviewed_by_id: nil,
        reviewed_at: nil,
      )

      if claim.save
        render json: {
                 claim: serialize_claim(claim.reload),
                 message: I18n.t("crimson_server_list.messages.claim_submitted"),
               },
               status: :created
      else
        render_validation_errors(claim)
      end
    rescue ActiveRecord::RecordNotUnique
      render_error(I18n.t("crimson_server_list.errors.claim_pending"), :unprocessable_entity)
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

    def review_claim
      claim =
        CrimsonServerList::ClaimRequest
          .includes(:requester, server: :owner)
          .find(params[:id])
      decision = params[:status].to_s
      unless %w[approved rejected].include?(decision)
        return render_error(I18n.t("crimson_server_list.errors.invalid_claim_decision"), :unprocessable_entity)
      end

      CrimsonServerList::ClaimRequest.transaction do
        claim.lock!
        unless claim.status == "pending"
          return render_error(I18n.t("crimson_server_list.errors.claim_already_reviewed"), :unprocessable_entity)
        end

        if decision == "approved"
          claim.server.lock!
          claim.server.update!(owner_id: claim.requester_id)
          claim.server.claim_requests.where(status: "pending").where.not(id: claim.id).update_all(
            status: "rejected",
            reviewed_by_id: current_user.id,
            reviewed_at: Time.zone.now,
            updated_at: Time.zone.now,
          )
        end

        claim.update!(
          status: decision,
          reviewed_by_id: current_user.id,
          reviewed_at: Time.zone.now,
        )
      end

      claim.reload
      render json: {
               claim: serialize_claim(claim),
               server: serialize_server(claim.server.reload, include_private: true),
               message:
                 I18n.t(
                   decision == "approved" ?
                     "crimson_server_list.messages.claim_approved" :
                     "crimson_server_list.messages.claim_rejected",
                 ),
             }
    end

    private

    def ensure_plugin_enabled
      raise Discourse::NotFound unless SiteSetting.crimson_server_list_enabled
    end

    def ensure_admin_user
      raise Discourse::InvalidAccess unless current_user&.admin?
    end

    def ensure_staff_user
      raise Discourse::InvalidAccess unless current_user&.staff?
    end

    def can_manage_server?(server)
      current_user.present? && (current_user.admin? || server.owner_id == current_user.id)
    end

    def viewer_payload(server: nil)
      public_server = server.nil? || (server.approved? && server.enabled?)
      claim =
        if server.present? && current_user.present?
          server.claim_requests.find_by(requester_id: current_user.id)
        end
      {
        logged_in: current_user.present?,
        is_admin: current_user&.admin? || false,
        is_staff: current_user&.staff? || false,
        can_submit:
          current_user.present? && SiteSetting.crimson_server_list_submission_enabled,
        can_vote:
          current_user.present? && public_server && SiteSetting.crimson_server_list_votes_enabled,
        can_review:
          current_user.present? && public_server && SiteSetting.crimson_server_list_reviews_enabled,
        can_edit: server.present? && can_manage_server?(server),
        can_delete: (server.present? && current_user&.staff?) || false,
        can_claim:
          server.present? && current_user.present? && !current_user.admin? && public_server &&
            server.owner_id != current_user.id && claim&.status != "pending",
        claim_status: claim&.status,
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
        game_details: server.game_details || {},
        game_detail_rows: serialize_game_details(server),
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
        view_count: server.view_count,
        can_edit: can_manage_server?(server),
        can_delete: current_user&.staff? || false,
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

    def serialize_game_details(server)
      values = server.game_details.respond_to?(:with_indifferent_access) ?
        server.game_details.with_indifferent_access :
        {}

      CrimsonServerList.game_fields(server.game_slug).filter_map do |field|
        value = values[field[:key]]
        next if value.blank?

        {
          key: field[:key],
          label: field[:label],
          value: value,
          unit: field[:unit],
        }
      end
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

    def serialize_claim(claim)
      requester = claim.requester
      server = claim.server
      {
        id: claim.id,
        status: claim.status,
        note: claim.note,
        created_at: claim.created_at&.iso8601,
        requester: {
          id: requester.id,
          username: requester.username,
          name: requester.name.presence || requester.username,
          avatar_url: requester.avatar_template.to_s.gsub("{size}", "96"),
          profile_url: "/u/#{requester.username_lower}",
        },
        server: {
          id: server.id,
          name: server.name,
          slug: server.slug,
          detail_url: "/servers/#{server.slug}",
          current_owner_username: server.owner&.username,
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
        game_details: CrimsonServerList::GAME_DETAIL_KEYS,
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
      server.game_details = normalize_game_details(server)
      %i[website_url discord_url banner_url language version mode description].each do |attribute|
        server.public_send("#{attribute}=", server.public_send(attribute).to_s.strip.presence)
      end
    end

    def normalize_game_details(server)
      source =
        if server.game_details.respond_to?(:to_unsafe_h)
          server.game_details.to_unsafe_h
        elsif server.game_details.respond_to?(:to_h)
          server.game_details.to_h
        else
          {}
        end

      allowed = CrimsonServerList.game_fields(server.game_slug).index_by { |field| field[:key] }
      source.each_with_object({}) do |(key, value), result|
        field = allowed[key.to_s]
        next unless field

        normalized = value.to_s.strip.first(100)
        result[key.to_s] = normalized if normalized.present?
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

    def track_public_view(server)
      return unless server.approved? && server.enabled?

      identity =
        if current_user.present?
          "user-#{current_user.id}"
        else
          fingerprint = "#{request.remote_ip}|#{request.user_agent.to_s.first(300)}"
          "guest-#{Digest::SHA256.hexdigest(fingerprint)}"
        end
      key = "crimson-server-list:view:#{server.id}:#{Time.zone.today}:#{identity}"
      return unless Discourse.redis.set(key, "1", nx: true, ex: 36.hours.to_i)

      CrimsonServerList::Server.where(id: server.id).update_all(
        "view_count = COALESCE(view_count, 0) + 1",
      )
      server.view_count = server.view_count.to_i + 1
    rescue StandardError => error
      Rails.logger.warn(
        "[#{CrimsonServerList::PLUGIN_NAME}] view counter failed for server #{server.id}: " \
          "#{error.class}: #{error.message}",
      )
    end

    def render_validation_errors(record)
      render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
    end

    def render_error(message, status)
      render json: { errors: [message] }, status: status
    end
  end
end
