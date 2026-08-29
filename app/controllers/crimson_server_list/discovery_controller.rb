# frozen_string_literal: true

module ::CrimsonServerList
  class DiscoveryController < CrimsonServerList::ServersController
    def index
      response.headers["Cache-Control"] = "private, no-store"
      result = CrimsonServerList::Discovery.new(params).call
      voted_ids = voted_server_ids(result[:records])

      render json: {
               servers:
                 result[:records].map do |server|
                   serialize_server(server, voted_today: voted_ids.include?(server.id))
                 end,
               pagination: {
                 page: result[:page],
                 per_page: result[:per_page],
                 total: result[:total],
                 total_pages: result[:total_pages],
                 has_more: result[:has_more],
               },
               filters: result[:filters],
               viewer: viewer_payload,
             }
    end
  end
end
