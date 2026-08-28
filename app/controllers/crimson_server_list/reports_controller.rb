# frozen_string_literal: true

module ::CrimsonServerList
  class ReportsController < ::ApplicationController
    requires_plugin CrimsonServerList::PLUGIN_NAME

    before_action :ensure_plugin_enabled
    before_action :ensure_logged_in, only: :create
    before_action :ensure_admin_user, only: %i[index update]
    before_action :ensure_reports_enabled, only: :create

    def create
      server = CrimsonServerList::Server.publicly_visible.find(params[:server_id])
      if server.owner_id == current_user.id
        return render_error(I18n.t("crimson_server_list.errors.report_own_server"), :unprocessable_entity)
      end

      existing =
        CrimsonServerList::Report.find_by(
          server_id: server.id,
          reporter_id: current_user.id,
          status: "pending",
        )
      if existing
        return render_error(I18n.t("crimson_server_list.errors.report_pending"), :unprocessable_entity)
      end

      return rate_limited unless acquire_throttle!(server)

      report =
        CrimsonServerList::Report.new(
          server: server,
          reporter: current_user,
          reason: params[:reason].to_s,
          details: params[:details].to_s.strip.presence,
          status: "pending",
        )

      if report.save
        render json: {
                 report: serialize_report(report, include_reporter: false),
                 message: I18n.t("crimson_server_list.messages.report_submitted"),
               },
               status: :created
      else
        render_validation_errors(report)
      end
    rescue ActiveRecord::RecordNotUnique
      render_error(I18n.t("crimson_server_list.errors.report_pending"), :unprocessable_entity)
    end

    def index
      reports =
        CrimsonServerList::Report
          .where(status: "pending")
          .includes(:reporter, server: :owner)
          .order(created_at: :asc)
          .limit(200)

      render json: { reports: reports.map { |report| serialize_report(report, include_reporter: true) } }
    end

    def update
      report =
        CrimsonServerList::Report
          .includes(:reporter, server: :owner)
          .find(params[:id])
      decision = params[:status].to_s
      unless %w[resolved dismissed].include?(decision)
        return render_error(I18n.t("crimson_server_list.errors.invalid_report_decision"), :unprocessable_entity)
      end

      report.with_lock do
        unless report.pending?
          return render_error(I18n.t("crimson_server_list.errors.report_already_reviewed"), :unprocessable_entity)
        end

        report.update!(
          status: decision,
          reviewed_by: current_user,
          reviewed_at: Time.zone.now,
          review_note: params[:review_note].to_s.strip.presence,
        )
      end

      render json: {
               report: serialize_report(report.reload, include_reporter: true),
               message:
                 I18n.t(
                   decision == "resolved" ?
                     "crimson_server_list.messages.report_resolved" :
                     "crimson_server_list.messages.report_dismissed",
                 ),
             }
    rescue ActiveRecord::RecordInvalid => error
      render_validation_errors(error.record)
    end

    private

    def ensure_plugin_enabled
      raise Discourse::NotFound unless SiteSetting.crimson_server_list_enabled
    end

    def ensure_reports_enabled
      return if SiteSetting.crimson_server_list_reports_enabled

      render_error(I18n.t("crimson_server_list.errors.reports_disabled"), :forbidden)
    end

    def ensure_admin_user
      raise Discourse::InvalidAccess unless current_user&.admin?
    end

    def acquire_throttle!(server)
      key = "crimson-server-list:report:create:#{current_user.id}:#{server.id}"
      Discourse.redis.set(key, "1", nx: true, ex: 60)
    end

    def rate_limited
      render_error(I18n.t("crimson_server_list.errors.report_rate_limited"), :too_many_requests)
    end

    def serialize_report(report, include_reporter:)
      payload = {
        id: report.id,
        reason: report.reason,
        details: report.details,
        status: report.status,
        created_at: report.created_at&.iso8601,
        reviewed_at: report.reviewed_at&.iso8601,
        review_note: report.review_note,
        server: {
          id: report.server.id,
          name: report.server.name,
          slug: report.server.slug,
          detail_url: "/servers/#{report.server.slug}",
          owner_username: report.server.owner&.username,
        },
      }

      if include_reporter
        payload[:reporter] = {
          id: report.reporter.id,
          username: report.reporter.username,
          name: report.reporter.name.presence || report.reporter.username,
          profile_url: "/u/#{report.reporter.username_lower}",
        }
      end

      payload
    end

    def render_validation_errors(record)
      render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
    end

    def render_error(message, status)
      render json: { errors: [message] }, status: status
    end
  end
end
