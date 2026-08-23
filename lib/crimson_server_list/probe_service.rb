# frozen_string_literal: true

module ::CrimsonServerList
  class ProbeService
    CACHE_PREFIX = "crimson-server-list:probe:v2"

    def self.call(server)
      endpoint =
        NetworkPolicy.resolve!(
          server.host,
          port: server.effective_query_port,
          game_slug: server.game_slug,
        )
      connect_timeout = NetworkPolicy.connect_timeout
      read_timeout = NetworkPolicy.read_timeout
      adapter =
        Adapters.for(server.game_slug).new(
          server: server,
          endpoint: endpoint,
          connect_timeout: connect_timeout,
          read_timeout: read_timeout,
        )

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      total_timeout = [connect_timeout + read_timeout + 0.75, 6.0].min
      result = Timeout.timeout(total_timeout) { adapter.call }
      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

      [result, elapsed_ms]
    end

    def self.cache_key(server_id)
      "#{CACHE_PREFIX}:#{server_id}"
    end

    def self.lock_key(server_id)
      "#{CACHE_PREFIX}:lock:#{server_id}"
    end

    def self.write_cache(server, result, elapsed_ms)
      payload = {
        status: result.status,
        players_online: result.players_online.to_i,
        players_max: result.players_max.to_i,
        adapter: result.adapter,
        supports_player_count: result.supports_player_count,
        last_checked_at: server.last_checked_at&.iso8601,
        last_response_ms: elapsed_ms,
      }
      ttl = SiteSetting.crimson_server_list_query_interval_minutes.to_i.clamp(1, 60).minutes * 2
      Discourse.cache.write(cache_key(server.id), payload, expires_in: ttl)
    end

    def self.read_cache(server_id)
      Discourse.cache.read(cache_key(server_id))
    rescue StandardError
      nil
    end
  end
end
