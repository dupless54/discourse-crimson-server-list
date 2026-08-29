# frozen_string_literal: true

module ::CrimsonServerList
  class OwnedServersController < CrimsonServerList::ServersController
    DEFAULT_PER_PAGE = 24
    MAX_PER_PAGE = 50
    MAX_PAGE = 200

    before_action :ensure_logged_in

    def index
      response.headers["Cache-Control"] = "private, no-store"

      scope = CrimsonServerList::Server.where(owner_id: current_user.id)
      total = scope.count
      page = bounded_positive_integer(params[:page], default: 1, maximum: MAX_PAGE)
      per_page =
        bounded_positive_integer(
          params[:per_page],
          default: DEFAULT_PER_PAGE,
          maximum: MAX_PER_PAGE,
        )

      servers =
        scope
          .includes(:owner)
          .order(updated_at: :desc, id: :desc)
          .offset((page - 1) * per_page)
          .limit(per_page)
          .to_a

      render json: {
               servers: servers.map { |server| serialize_owned_server(server) },
               stats: ownership_stats(scope, total: total),
               pagination: {
                 page: page,
                 per_page: per_page,
                 total: total,
                 total_pages: total.zero? ? 0 : ((total + per_page - 1) / per_page),
                 has_more: page * per_page < total,
               },
             }
    end

    private

    def serialize_owned_server(server)
      serialize_server(server, include_private: true).merge(
        management: {
          publication_state: publication_state(server),
          can_edit: true,
          can_refresh:
            SiteSetting.crimson_server_list_live_query_enabled && server.approved? && server.enabled? &&
              server.monitoring_enabled?,
          edit_requires_approval:
            !current_user.admin? && SiteSetting.crimson_server_list_owner_edits_require_approval,
        },
      )
    end

    def ownership_stats(scope, total:)
      {
        total: total,
        published: scope.where(approved: true, enabled: true).count,
        pending: scope.where(approved: false, enabled: true).count,
        disabled: scope.where(enabled: false).count,
        online: scope.where(status: "online").count,
        monitored: scope.where(monitoring_enabled: true).count,
        verified: scope.where.not(verified_at: nil).count,
      }
    end

    def publication_state(server)
      return "disabled" unless server.enabled?
      return "pending" unless server.approved?

      "published"
    end

    def bounded_positive_integer(value, default:, maximum:)
      parsed = value.to_s.to_i
      return default if parsed <= 0

      [parsed, maximum].min
    end
  end
end
