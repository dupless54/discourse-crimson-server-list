# frozen_string_literal: true

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
  end
end
