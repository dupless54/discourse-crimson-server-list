# frozen_string_literal: true

Notification.types[:crimson_server_back_online] = 12_001 unless Notification.types.valid?(:crimson_server_back_online)

module ::Jobs
  class CrimsonServerListProbe < ::Jobs::Base
    sidekiq_options retry: 2

    def execute(args)
      return unless SiteSetting.crimson_server_list_enabled
      return unless SiteSetting.crimson_server_list_live_query_enabled

      server = ::CrimsonServerList::Server.find_by(id: args[:server_id])
      return unless server&.approved? && server.enabled? && server.monitoring_enabled?

      unless args[:force]
        interval = SiteSetting.crimson_server_list_query_interval_minutes.to_i.clamp(1, 60).minutes
        return if server.last_checked_at.present? && server.last_checked_at > interval.ago
      end

      lock_key = ::CrimsonServerList::ProbeService.lock_key(server.id)
      lock_ttl = 30
      lock_acquired = Discourse.redis.set(lock_key, "1", nx: true, ex: lock_ttl)
      return unless lock_acquired

      previous_status = server.status
      result, elapsed_ms = ::CrimsonServerList::ProbeService.call(server)
      result.players_online = result.players_online.to_i.clamp(0, 1_000_000)
      result.players_max = result.players_max.to_i.clamp(0, 1_000_000)
      if result.players_max.positive?
        result.players_online = [result.players_online, result.players_max].min
      end
      checked_at = Time.zone.now
      attributes = {
        status: result.status,
        players_online: result.players_online.to_i,
        players_max: result.players_max.to_i,
        last_query_error: nil,
        last_response_ms: elapsed_ms,
        last_checked_at: checked_at,
      }
      attributes[:version] = result.version.to_s.first(60) if result.version.present? && server.version.blank?
      server.update_columns(attributes)
      safe_record_history(
        server,
        status: result.status,
        checked_at: checked_at,
        response_ms: elapsed_ms,
        players_online: result.players_online,
        players_max: result.players_max,
        supports_player_count: result.supports_player_count,
      )
      safe_enqueue_follow_notification(
        server,
        previous_status: previous_status,
        current_status: result.status,
        checked_at: checked_at,
      )
      server.reload
      ::CrimsonServerList::ProbeService.write_cache(server, result, elapsed_ms)
    rescue ::CrimsonServerList::NetworkPolicy::Error => error
      record_failure(server, "unknown", "security_policy: #{error.message}")
    rescue Timeout::Error, SocketError, SystemCallError, IOError, EOFError,
           ::CrimsonServerList::Adapters::ProbeError, JSON::ParserError => error
      record_failure(server, "offline", "#{error.class}: #{error.message}")
    rescue StandardError => error
      record_failure(server, "unknown", "#{error.class}: #{error.message}")
      raise
    ensure
      Discourse.redis.del(lock_key) if defined?(lock_acquired) && lock_acquired
    end

    private

    def record_failure(server, status, message)
      return unless server&.persisted?

      checked_at = Time.zone.now
      server.update_columns(
        status: status,
        players_online: 0,
        players_max: 0,
        last_query_error: message.to_s.first(500),
        last_response_ms: nil,
        last_checked_at: checked_at,
      )
      safe_record_history(server, status: status, checked_at: checked_at)
      Discourse.cache.delete(::CrimsonServerList::ProbeService.cache_key(server.id))
    end

    def safe_record_history(server, **attributes)
      ::CrimsonServerList::UptimeHistory.record!(server: server, **attributes)
    rescue StandardError => error
      Rails.logger.warn(
        "[CrimsonServerList] uptime sample failed for server #{server.id}: " \
          "#{error.class}: #{error.message}",
      )
    end

    def safe_enqueue_follow_notification(server, previous_status:, current_status:, checked_at:)
      return unless SiteSetting.crimson_server_list_follows_enabled
      return unless previous_status == "offline" && current_status == "online"

      Jobs.enqueue(
        :crimson_server_list_follow_notification,
        server_id: server.id,
        event: "back_online",
        transition_at: checked_at.iso8601,
      )
    rescue StandardError => error
      Rails.logger.warn(
        "[CrimsonServerList] follow notification enqueue failed for server #{server.id}: " \
          "#{error.class}: #{error.message}",
      )
    end
  end

  class CrimsonServerListFollowNotification < ::Jobs::Base
    BATCH_SIZE = 200
    EVENT_BACK_ONLINE = "back_online"

    def execute(args)
      return unless SiteSetting.crimson_server_list_enabled
      return unless SiteSetting.crimson_server_list_follows_enabled
      return unless args[:event].to_s == EVENT_BACK_ONLINE

      server = ::CrimsonServerList::Server.publicly_visible.find_by(id: args[:server_id])
      return unless server&.status == "online"

      transition_at = parse_transition_at(args[:transition_at])
      return unless transition_at

      follows =
        ::CrimsonServerList::Follow
          .where(server_id: server.id, notifications_enabled: true)
          .where("id > ?", args[:after_id].to_i)
          .includes(:user)
          .order(:id)
          .limit(BATCH_SIZE)
          .to_a

      follows.each { |follow| notify_follow(follow, server, transition_at) }

      return unless follows.length == BATCH_SIZE

      Jobs.enqueue(
        :crimson_server_list_follow_notification,
        server_id: server.id,
        event: EVENT_BACK_ONLINE,
        transition_at: transition_at.iso8601,
        after_id: follows.last.id,
      )
    end

    private

    def parse_transition_at(value)
      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def notify_follow(follow, server, transition_at)
      ::CrimsonServerList::Follow.transaction do
        locked_follow = ::CrimsonServerList::Follow.lock.find_by(id: follow.id)
        next unless locked_follow&.notifications_enabled?
        next if locked_follow.last_online_notification_at.present? &&
          locked_follow.last_online_notification_at >= transition_at

        user = locked_follow.user
        next unless user&.active?

        notification =
          Notification.new(
            notification_type: Notification.types[:crimson_server_back_online],
            user_id: user.id,
            data: {
              server_id: server.id,
              server_name: server.name,
              detail_url: "/servers/#{server.slug}",
              event: EVENT_BACK_ONLINE,
            }.to_json,
          )
        notification.skip_send_email = true
        notification.save!

        locked_follow.update!(last_online_notification_at: transition_at)
      end
    end
  end
end
