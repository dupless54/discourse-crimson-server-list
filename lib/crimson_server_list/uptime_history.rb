# frozen_string_literal: true

module ::CrimsonServerList
  module UptimeHistory
    BUCKET_SECONDS = 10.minutes.to_i
    MAX_RETENTION_DAYS = 90
    MAX_SERIES_POINTS = 240
    RANGE_SECONDS = {
      "24h" => 24.hours,
      "7d" => 7.days,
      "30d" => 30.days,
    }.freeze

    module_function

    def record!(
      server:,
      status:,
      checked_at:,
      response_ms: nil,
      players_online: nil,
      players_max: nil,
      supports_player_count: false
    )
      return unless SiteSetting.crimson_server_list_uptime_history_enabled

      supports_player_count = !!supports_player_count
      attributes = {
        server_id: server.id,
        sampled_at: bucket_time(checked_at),
        status: status.to_s,
        response_ms: normalized_nonnegative(response_ms),
        supports_player_count: supports_player_count,
        players_online:
          supports_player_count ? normalized_nonnegative(players_online) : nil,
        players_max: supports_player_count ? normalized_nonnegative(players_max) : nil,
      }

      if attributes[:players_max].to_i.positive?
        attributes[:players_online] = [attributes[:players_online].to_i, attributes[:players_max]].min
      end

      CrimsonServerList::UptimeSample.upsert(
        attributes,
        unique_by: "idx_crimson_uptime_server_sample",
      )
    rescue ActiveRecord::InvalidForeignKey
      # The listing may have been deleted after the probe began. The FK prevents
      # orphan history rows; losing this final sample is safe.
      nil
    end

    def retention_days
      SiteSetting.crimson_server_list_uptime_history_retention_days.to_i.clamp(7, MAX_RETENTION_DAYS)
    end

    def range_duration(value)
      RANGE_SECONDS.fetch(value.to_s, RANGE_SECONDS.fetch("24h"))
    end

    def range_key(value)
      RANGE_SECONDS.key?(value.to_s) ? value.to_s : "24h"
    end

    def summarize(samples, range:, now: Time.zone.now)
      known = samples.select { |sample| %w[online offline].include?(sample.status) }
      online_count = known.count { |sample| sample.status == "online" }
      uptime_percent =
        if known.empty?
          nil
        else
          ((online_count.to_f / known.length) * 100).round(1)
        end

      {
        range: range_key(range),
        from: (now - range_duration(range)).iso8601,
        to: now.iso8601,
        sample_count: samples.length,
        known_sample_count: known.length,
        online_sample_count: online_count,
        uptime_percent: uptime_percent,
        series: compact_series(samples),
      }
    end

    def bucket_time(time)
      timestamp = time.to_time.to_i
      Time.at((timestamp / BUCKET_SECONDS) * BUCKET_SECONDS).utc
    end

    def compact_series(samples)
      return samples.map { |sample| serialize_sample(sample) } if samples.length <= MAX_SERIES_POINTS

      stride = (samples.length.to_f / MAX_SERIES_POINTS).ceil
      selected = samples.each_with_index.filter_map { |sample, index| sample if (index % stride).zero? }
      selected << samples.last unless selected.last&.id == samples.last&.id
      selected.map { |sample| serialize_sample(sample) }
    end

    def serialize_sample(sample)
      {
        sampled_at: sample.sampled_at&.iso8601,
        status: sample.status,
        response_ms: sample.response_ms,
        supports_player_count: sample.supports_player_count,
        players_online: sample.supports_player_count ? sample.players_online : nil,
        players_max: sample.supports_player_count ? sample.players_max : nil,
      }
    end

    def normalized_nonnegative(value)
      return nil if value.nil?

      value.to_i.clamp(0, 1_000_000)
    end
    private_class_method :normalized_nonnegative
  end
end
