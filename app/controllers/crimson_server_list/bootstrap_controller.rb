# frozen_string_literal: true

module ::CrimsonServerList
  class BootstrapController < CrimsonServerList::ServersController
    def index
      response.headers["Cache-Control"] = "private, no-store"
      public_scope = CrimsonServerList::Server.publicly_visible
      game_counts = public_scope.group(:game_slug).count
      tag_counts = Hash.new(0)
      public_scope.pluck(:tags).each do |server_tags|
        Array(server_tags).each { |tag| tag_counts[tag] += 1 }
      end

      payload = {
        games:
          CrimsonServerList::GAMES.map do |game|
            game.merge(
              server_count: game_counts.fetch(game[:slug], 0),
              category_url: "/servers?game=#{game[:slug]}",
            )
          end,
        tags:
          tag_counts
            .sort_by { |tag, count| [-count, tag] }
            .map do |tag, count|
              {
                slug: tag,
                name: tag.tr("-", " "),
                server_count: count,
                url: "/servers?tag=#{tag}",
              }
            end,
        stats: {
          server_count: public_scope.count,
          vote_count: public_scope.sum(:vote_count),
          online_count: public_scope.where(status: "online").count,
          game_count: game_counts.count { |_slug, count| count.positive? },
          review_count: public_scope.sum(:review_count),
        },
        viewer: viewer_payload,
      }

      if current_user&.admin?
        payload[:pending_servers] =
          CrimsonServerList::Server
            .where(approved: false, enabled: true)
            .includes(:owner)
            .order(created_at: :asc)
            .limit(100)
            .map { |server| serialize_server(server, include_private: true) }
        payload[:pending_claims] =
          CrimsonServerList::ClaimRequest
            .where(status: "pending")
            .includes(:requester, server: :owner)
            .order(created_at: :asc)
            .limit(100)
            .map { |claim| serialize_claim(claim) }
      end

      render json: payload
    end
  end
end
