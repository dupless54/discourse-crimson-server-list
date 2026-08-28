# frozen_string_literal: true

module ::CrimsonServerList
  class VerificationsController < ::ApplicationController
    requires_plugin CrimsonServerList::PLUGIN_NAME

    before_action :ensure_plugin_enabled
    before_action :ensure_logged_in, only: %i[start check]
    before_action :ensure_verification_enabled, only: %i[start check]

    def index
      ids =
        params[:ids]
          .to_s
          .split(",")
          .filter_map { |value| Integer(value, exception: false) }
          .select(&:positive?)
          .uniq
          .first(200)

      servers = CrimsonServerList::Server.publicly_visible.where(id: ids).order(:id)
      render json: {
               verifications:
                 servers.map do |server|
                   {
                     server_id: server.id,
                     verified: server.verified?,
                     verified_at: server.verified_at&.iso8601,
                     verification_method: server.verification_method,
                   }
                 end,
             }
    end

    def show
      server = CrimsonServerList::Server.find(params[:id])
      publicly_visible = server.approved? && server.enabled?
      raise Discourse::NotFound unless publicly_visible || can_manage_server?(server)

      render json: { verification: serialize_verification(server, include_private: can_manage_server?(server)) }
    end

    def start
      server = managed_server
      return rate_limited unless acquire_throttle!("start", server, 10)

      challenge = CrimsonServerList::VerificationService.start!(server)
      render json: {
               verification:
                 serialize_verification(server.reload, include_private: true).merge(
                   challenge: challenge,
                 ),
               message: I18n.t("crimson_server_list.messages.verification_started"),
             }
    rescue CrimsonServerList::VerificationService::NotEligible
      render_error(I18n.t("crimson_server_list.errors.verification_not_eligible"), :unprocessable_entity)
    end

    def check
      server = managed_server
      return rate_limited unless acquire_throttle!("check", server, 30)

      CrimsonServerList::VerificationService.verify!(server)
      render json: {
               verification: serialize_verification(server, include_private: true),
               message: I18n.t("crimson_server_list.messages.verification_succeeded"),
             }
    rescue CrimsonServerList::VerificationService::NotEligible
      render_error(I18n.t("crimson_server_list.errors.verification_not_eligible"), :unprocessable_entity)
    rescue CrimsonServerList::VerificationService::ChallengeMissing
      render_error(I18n.t("crimson_server_list.errors.verification_challenge_missing"), :unprocessable_entity)
    rescue CrimsonServerList::VerificationService::ChallengeExpired
      render_error(I18n.t("crimson_server_list.errors.verification_challenge_expired"), :unprocessable_entity)
    rescue CrimsonServerList::VerificationService::VerificationFailed
      render_error(I18n.t("crimson_server_list.errors.verification_failed"), :unprocessable_entity)
    rescue CrimsonServerList::VerificationService::LookupFailed
      render_error(I18n.t("crimson_server_list.errors.verification_lookup_failed"), :service_unavailable)
    end

    private

    def ensure_plugin_enabled
      raise Discourse::NotFound unless SiteSetting.crimson_server_list_enabled
    end

    def ensure_verification_enabled
      return if SiteSetting.crimson_server_list_verification_enabled

      render_error(I18n.t("crimson_server_list.errors.verification_disabled"), :forbidden)
    end

    def managed_server
      server = CrimsonServerList::Server.find(params[:id])
      return server if can_manage_server?(server)

      raise Discourse::InvalidAccess
    end

    def can_manage_server?(server)
      current_user.present? && (current_user.admin? || server.owner_id == current_user.id)
    end

    def acquire_throttle!(action, server, seconds)
      key = "crimson-server-list:verification:#{action}:#{current_user.id}:#{server.id}"
      Discourse.redis.set(key, "1", nx: true, ex: seconds)
    end

    def rate_limited
      render_error(I18n.t("crimson_server_list.errors.verification_rate_limited"), :too_many_requests)
    end

    def serialize_verification(server, include_private: false)
      payload = {
        server_id: server.id,
        verified: server.verified?,
        verified_at: server.verified_at&.iso8601,
        verification_method: server.verification_method,
      }

      if include_private
        payload.merge!(
          eligible: CrimsonServerList::VerificationService.eligible?(server),
          pending: CrimsonServerList::VerificationService.pending?(server),
          record_name: CrimsonServerList::VerificationService.record_name(server),
          expires_at: server.verification_expires_at&.iso8601,
        )
      end

      payload
    end

    def render_error(message, status)
      render json: { errors: [message] }, status: status
    end
  end
end
