# frozen_string_literal: true

module ::CrimsonServerList
  class FollowsController < ::ApplicationController
    requires_plugin CrimsonServerList::PLUGIN_NAME

    MAX_FOLLOWS_PER_USER = 500
    MAX_MUTATIONS_PER_HOUR = 120

    before_action :ensure_plugin_enabled
    before_action :ensure_logged_in
    before_action :ensure_follows_enabled

    def index
      follows =
        CrimsonServerList::Follow
          .where(user_id: current_user.id)
          .joins(:server)
          .merge(CrimsonServerList::Server.publicly_visible)
          .includes(:server)
          .order("crimson_server_follows.updated_at DESC")
          .limit(MAX_FOLLOWS_PER_USER)

      render json: { follows: follows.map { |follow| serialize_follow(follow) } }
    end

    def show
      server = CrimsonServerList::Server.publicly_visible.find(params[:server_id])
      follow = CrimsonServerList::Follow.find_by(server_id: server.id, user_id: current_user.id)

      render json: follow_state(server, follow)
    end

    def update
      server = CrimsonServerList::Server.publicly_visible.find(params[:server_id])
      follow = CrimsonServerList::Follow.find_by(server_id: server.id, user_id: current_user.id)

      if follow.nil?
        if CrimsonServerList::Follow.where(user_id: current_user.id).count >= MAX_FOLLOWS_PER_USER
          return render_error(I18n.t("crimson_server_list.errors.follow_limit_reached"), :unprocessable_entity)
        end

        follow = CrimsonServerList::Follow.new(server: server, user: current_user)
      end

      desired_notifications = notification_value(follow)
      follow.notifications_enabled = desired_notifications

      if follow.persisted? && !follow.changed?
        return render json: follow_state(server, follow)
      end

      created = follow.new_record?
      with_mutation_rate_limit do
        begin
          follow.save!
        rescue ActiveRecord::RecordNotUnique
          follow = CrimsonServerList::Follow.find_by!(server_id: server.id, user_id: current_user.id)
          follow.update!(notifications_enabled: desired_notifications) if follow.notifications_enabled != desired_notifications
          created = false
        end

        render json: {
                 **follow_state(server, follow.reload),
                 message:
                   I18n.t(
                     created ?
                       "crimson_server_list.messages.followed" :
                       "crimson_server_list.messages.follow_updated",
                   ),
               },
               status: created ? :created : :ok
      end
    rescue ActiveRecord::RecordInvalid => error
      render_validation_errors(error.record)
    end

    def destroy
      follow = CrimsonServerList::Follow.find_by(server_id: params[:server_id], user_id: current_user.id)
      return render json: { server_id: params[:server_id].to_i, favorited: false, notifications_enabled: false } unless follow

      server_id = follow.server_id
      with_mutation_rate_limit do
        follow.destroy!
        render json: {
                 server_id: server_id,
                 favorited: false,
                 notifications_enabled: false,
                 message: I18n.t("crimson_server_list.messages.unfollowed"),
               }
      end
    end

    private

    def ensure_plugin_enabled
      raise Discourse::NotFound unless SiteSetting.crimson_server_list_enabled
    end

    def ensure_follows_enabled
      return if SiteSetting.crimson_server_list_follows_enabled

      render_error(I18n.t("crimson_server_list.errors.follows_disabled"), :forbidden)
    end

    def notification_value(follow)
      return follow.notifications_enabled unless params.key?(:notifications_enabled)

      ActiveModel::Type::Boolean.new.cast(params[:notifications_enabled])
    end

    def with_mutation_rate_limit
      limiter =
        RateLimiter.new(
          current_user,
          "crimson-server-list-follow-mutation",
          MAX_MUTATIONS_PER_HOUR,
          1.hour,
        )
      performed = limiter.performed!(raise_error: false)
      return render_error(I18n.t("crimson_server_list.errors.follow_rate_limited"), :too_many_requests) unless performed

      result = yield
      limiter.rollback! if response.status.to_i >= 400
      result
    rescue StandardError
      limiter.rollback! if performed
      raise
    end

    def follow_state(server, follow)
      {
        server_id: server.id,
        favorited: follow.present?,
        notifications_enabled: follow&.notifications_enabled? || false,
        followed_at: follow&.created_at&.iso8601,
      }
    end

    def serialize_follow(follow)
      server = follow.server
      {
        server_id: server.id,
        favorited: true,
        notifications_enabled: follow.notifications_enabled?,
        followed_at: follow.created_at&.iso8601,
        updated_at: follow.updated_at&.iso8601,
        server: {
          id: server.id,
          slug: server.slug,
          detail_url: "/servers/#{server.slug}",
          game_slug: server.game_slug,
          name: server.name,
          short_description: server.short_description,
          banner_url: server.banner_url,
          status: server.status,
          verified: server.verified?,
        },
      }
    end

    def render_validation_errors(record)
      render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
    end

    def render_error(message, status)
      render json: { errors: [message] }, status: status
    end
  end
end
