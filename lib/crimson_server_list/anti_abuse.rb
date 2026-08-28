# frozen_string_literal: true

module ::CrimsonServerList
  module AntiAbuse
    SUBMISSION_LIMIT = { max: 5, window: 1.day }.freeze
    VOTE_LIMIT = { max: 100, window: 1.day }.freeze
    REVIEW_LIMIT = { max: 30, window: 1.hour }.freeze
    CLAIM_LIMIT = { max: 10, window: 1.day }.freeze

    def create
      return super unless SiteSetting.crimson_server_list_submission_enabled

      with_crimson_rate_limit("submission", SUBMISSION_LIMIT, "submission_rate_limited") { super }
    end

    def vote
      return super unless SiteSetting.crimson_server_list_votes_enabled

      server = CrimsonServerList::Server.publicly_visible.find(params[:id])
      if server.owner_id == current_user.id
        return render_error(I18n.t("crimson_server_list.errors.own_server_vote"), :unprocessable_entity)
      end

      existing = CrimsonServerList::Vote.exists?(
        server_id: server.id,
        user_id: current_user.id,
        voted_on: Time.zone.today,
      )
      return super if existing

      with_crimson_rate_limit("vote", VOTE_LIMIT, "vote_rate_limited") { super }
    end

    def request_claim
      server = CrimsonServerList::Server.publicly_visible.find(params[:id])
      return super if server.owner_id == current_user.id

      existing = CrimsonServerList::ClaimRequest.exists?(
        server_id: server.id,
        requester_id: current_user.id,
        status: "pending",
      )
      return super if existing

      with_crimson_rate_limit("claim", CLAIM_LIMIT, "claim_rate_limited") { super }
    end

    def upsert_review
      return super unless SiteSetting.crimson_server_list_reviews_enabled

      server = CrimsonServerList::Server.publicly_visible.find(params[:id])
      if server.owner_id == current_user.id
        return render_error(I18n.t("crimson_server_list.errors.own_server_review"), :unprocessable_entity)
      end

      with_crimson_rate_limit("review", REVIEW_LIMIT, "review_rate_limited") { super }
    end

    private

    def viewer_payload(server: nil)
      payload = super
      own_server = server.present? && current_user.present? && server.owner_id == current_user.id

      if own_server
        payload[:can_vote] = false
        payload[:can_review] = false
      end

      payload
    end

    def with_crimson_rate_limit(type, limit, error_key)
      limiter =
        RateLimiter.new(
          current_user,
          "crimson-server-list-#{type}",
          limit.fetch(:max),
          limit.fetch(:window),
        )
      performed = limiter.performed!(raise_error: false)
      return render_error(I18n.t("crimson_server_list.errors.#{error_key}"), :too_many_requests) unless performed

      result = yield
      limiter.rollback! if response.status.to_i >= 400
      result
    rescue StandardError
      limiter.rollback! if performed
      raise
    end
  end
end
