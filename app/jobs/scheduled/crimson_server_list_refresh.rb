# frozen_string_literal: true

module ::Jobs
  class CrimsonServerListRefresh < ::Jobs::Scheduled
    every 1.minute

    def execute(_args)
      return unless SiteSetting.crimson_server_list_enabled
      return unless SiteSetting.crimson_server_list_live_query_enabled

      interval = SiteSetting.crimson_server_list_query_interval_minutes.to_i.clamp(1, 60).minutes
      ::CrimsonServerList::Server
        .publicly_visible
        .where(monitoring_enabled: true)
        .where("last_checked_at IS NULL OR last_checked_at < ?", interval.ago)
        .order(Arel.sql("last_checked_at ASC NULLS FIRST"))
        .limit(100)
        .pluck(:id)
        .each { |server_id| Jobs.enqueue(:crimson_server_list_probe, server_id: server_id) }
    end
  end
end
