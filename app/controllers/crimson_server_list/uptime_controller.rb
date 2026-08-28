# frozen_string_literal: true

module ::CrimsonServerList
  class UptimeController < ::ApplicationController
    requires_plugin CrimsonServerList::PLUGIN_NAME

    MAX_SAMPLES = 5_000

    before_action :ensure_plugin_enabled

    def show
      raise Discourse::NotFound unless SiteSetting.crimson_server_list_uptime_history_enabled

      server = CrimsonServerList::Server.publicly_visible.find(params[:id])
      range = CrimsonServerList::UptimeHistory.range_key(params[:range])
      now = Time.zone.now
      from = now - CrimsonServerList::UptimeHistory.range_duration(range)
      samples =
        server
          .uptime_samples
          .where(sampled_at: from..now)
          .order(:sampled_at)
          .limit(MAX_SAMPLES)
          .to_a

      render json: {
               server: {
                 id: server.id,
                 name: server.name,
                 slug: server.slug,
                 detail_url: "/servers/#{server.slug}",
               },
               uptime: CrimsonServerList::UptimeHistory.summarize(samples, range: range, now: now),
             }
    end

    private

    def ensure_plugin_enabled
      raise Discourse::NotFound unless SiteSetting.crimson_server_list_enabled
    end
  end
end
