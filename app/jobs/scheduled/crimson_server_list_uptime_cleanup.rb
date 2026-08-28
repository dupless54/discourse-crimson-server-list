# frozen_string_literal: true

module ::Jobs
  class CrimsonServerListUptimeCleanup < ::Jobs::Scheduled
    every 1.day

    def execute(_args)
      return unless SiteSetting.crimson_server_list_enabled

      cutoff = CrimsonServerList::UptimeHistory.retention_days.days.ago
      CrimsonServerList::UptimeSample
        .where("sampled_at < ?", cutoff)
        .in_batches(of: 5_000)
        .delete_all
    end
  end
end
