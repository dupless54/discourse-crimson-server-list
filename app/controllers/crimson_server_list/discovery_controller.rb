# frozen_string_literal: true

module ::CrimsonServerList
  class DiscoveryController < CrimsonServerList::ServersController
    PRIVATE_DISCOVERY_FIELDS = %i[
      host
      port
      query_port
      address
      query_adapter
      last_response_ms
      last_query_error
    ].freeze

    def index
      response.headers["Cache-Control"] = "private, no-store"
      result = CrimsonServerList::Discovery.new(params).call
      voted_ids = voted_server_ids(result[:records])

      render json: {
               servers:
                 result[:records].map do |server|
                   serialize_discovery_server(server, voted_ids)
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

    private

    def serialize_discovery_server(server, voted_ids)
      serialize_server(server, voted_today: voted_ids.include?(server.id)).except(
        *PRIVATE_DISCOVERY_FIELDS,
      )
    end
  end
end
