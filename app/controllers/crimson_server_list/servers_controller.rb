# frozen_string_literal: true

module ::CrimsonServerList
  class ServersController < ::ApplicationController
    requires_plugin CrimsonServerList::PLUGIN_NAME

    before_action :ensure_plugin_enabled
    before_action :ensure_logged_in, only: %i[create vote]
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
        },
        viewer: {
          logged_in: current_user.present?,
          is_admin: current_user&.admin? || false,
          can_submit:
            current_user.present? && SiteSetting.crimson_server_list_submission_enabled,
          can_vote:
            current_user.present? && SiteSetting.crimson_server_list_votes_enabled,
        },
      }

      if current_user&.admin?
        payload[:pending_servers] =
          CrimsonServerList::Server
            .where(approved: false, enabled: true)
            .order(created_at: :asc)
            .limit(100)
            .map { |server| serialize_server(server, include_private: true) }
      end

      render json: payload
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
        render json: {
                 server: serialize_server(server),
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

    def update
      server = CrimsonServerList::Server.find(params[:id])
      server.assign_attributes(admin_server_params)
      normalize_server(server)

      if server.save
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

      payload = {
        id: server.id,
        slug: server.slug,
        game_slug: server.game_slug,
        game: game,
        name: server.name,
        short_description: server.short_description,
        description: server.description,
        host: server.host,
        port: server.port,
        address: "#{server.host}:#{server.port}",
        website_url: server.website_url,
        discord_url: server.discord_url,
        banner_url: server.banner_url,
        country_code: server.country_code,
        language: server.language,
        version: server.version,
        mode: server.mode,
        status: server.status,
        status_label: I18n.t("crimson_server_list.statuses.#{server.status}"),
        players_online: server.players_online,
        players_max: server.players_max,
        vote_count: server.vote_count,
        featured: server.featured,
        voted_today: voted_today,
        created_at: server.created_at&.iso8601,
        owner:
          if owner
            {
              id: owner.id,
              username: owner.username,
              name: owner.name.presence || owner.username,
              avatar_url: owner.avatar_template.to_s.gsub("{size}", "48"),
            }
          end,
      }

      if include_private
        payload[:approved] = server.approved
        payload[:enabled] = server.enabled
      end

      payload
    end

    def server_params
      params.permit(
        :game_slug,
        :name,
        :short_description,
        :description,
        :host,
        :port,
        :website_url,
        :discord_url,
        :banner_url,
        :country_code,
        :language,
        :version,
        :mode,
      )
    end

    def admin_server_params
      params.permit(
        :approved,
        :enabled,
        :featured,
        :status,
        :players_online,
        :players_max,
      )
    end

    def normalize_server(server)
      server.host = server.host.to_s.strip.downcase
      server.country_code = server.country_code.to_s.strip.upcase
      %i[website_url discord_url banner_url language version mode].each do |attribute|
        server.public_send("#{attribute}=", server.public_send(attribute).to_s.strip.presence)
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
