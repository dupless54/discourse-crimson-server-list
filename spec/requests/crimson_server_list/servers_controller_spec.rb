# frozen_string_literal: true

RSpec.describe CrimsonServerList::ServersController do
  let!(:owner) { Fabricate(:user) }
  let!(:member) { Fabricate(:user) }
  let!(:claimant) { Fabricate(:user) }
  let!(:admin) { Fabricate(:admin) }

  before do
    SiteSetting.crimson_server_list_enabled = true
    SiteSetting.crimson_server_list_submission_enabled = true
    SiteSetting.crimson_server_list_require_approval = true
    SiteSetting.crimson_server_list_votes_enabled = true
    SiteSetting.crimson_server_list_reviews_enabled = true
  end

  def server_attributes(name: "Crimson Test Server")
    {
      game_slug: "minecraft",
      name: name,
      short_description: "A test server used by the plugin request specs.",
      description: "Stable request-spec fixture data.",
      host: "play.example.net",
      port: 25_565,
      country_code: "TR",
      language: "tr",
      tags: %w[survival community],
      game_details: { edition: "Java", server_type: "Survival" },
    }
  end

  def create_server(owner:, name: "Crimson Published Server")
    server =
      CrimsonServerList::Server.create!(
        **server_attributes(name: name),
        owner: owner,
        approved: true,
        enabled: true,
        status: "online",
        players_online: 12,
        players_max: 100,
      )

    expect(CrimsonServerList::Server.publicly_visible.exists?(server.id)).to eq(true)
    server
  end

  def expect_route(path, method:, action:, id: nil)
    route = Rails.application.routes.recognize_path(path, method: method)
    expect(route[:controller]).to eq("crimson_server_list/servers")
    expect(route[:action]).to eq(action)
    expect(route[:id]).to eq(id.to_s) if id
    expect(route[:format]).to eq("json")
  end

  def expect_status(status)
    expect(response.status).to eq(status),
                               "response=#{response.body.inspect}; path=#{request.path.inspect}; " \
                                 "path_parameters=#{request.path_parameters.inspect}"
  end

  describe "POST /crimson-server-list/servers" do
    it "requires a signed-in user" do
      expect do
        post "/crimson-server-list/servers.json", params: server_attributes
      end.not_to change(CrimsonServerList::Server, :count)

      expect_status(403)
    end

    it "derives ownership and approval state on the server" do
      sign_in(member)

      expect do
        post "/crimson-server-list/servers.json",
             params: server_attributes.merge(owner_id: owner.id, approved: true)
      end.to change(CrimsonServerList::Server, :count).by(1)

      expect_status(201)
      server = CrimsonServerList::Server.order(:id).last
      expect(server.owner_id).to eq(member.id)
      expect(server.approved).to eq(false)
    end

    it "returns 429 without creating a server when the submission limiter denies the request" do
      sign_in(member)
      limiter = instance_double(RateLimiter)
      allow(limiter).to receive(:performed!).with(raise_error: false).and_return(false)
      allow(RateLimiter).to receive(:new).and_return(limiter)

      expect do
        post "/crimson-server-list/servers.json", params: server_attributes
      end.not_to change(CrimsonServerList::Server, :count)

      expect_status(429)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("crimson_server_list.errors.submission_rate_limited"),
      )
    end

    it "rolls back a consumed limiter slot when validation rejects the submission" do
      sign_in(member)
      limiter = instance_double(RateLimiter)
      allow(limiter).to receive(:performed!).with(raise_error: false).and_return(true)
      allow(limiter).to receive(:rollback!)
      allow(RateLimiter).to receive(:new).and_return(limiter)

      post "/crimson-server-list/servers.json", params: server_attributes(name: "")

      expect_status(422)
      expect(limiter).to have_received(:rollback!).once
    end
  end

  describe "PUT /crimson-server-list/servers/:id" do
    it "does not let another member edit someone else's server" do
      server = create_server(owner: owner)
      sign_in(member)

      put "/crimson-server-list/servers/#{server.id}.json", params: { name: "Hijacked" }

      expect_status(403)
      expect(server.reload.name).to eq("Crimson Published Server")
    end
  end

  describe "GET /crimson-server-list/servers/:slug" do
    it "hides vote and review actions from the listing owner but not other members" do
      server = create_server(owner: owner)
      path = "/crimson-server-list/servers/#{server.slug}.json"

      sign_in(owner)
      get path
      expect_status(200)
      expect(response.parsed_body.dig("viewer", "can_vote")).to eq(false)
      expect(response.parsed_body.dig("viewer", "can_review")).to eq(false)

      sign_in(member)
      get path
      expect_status(200)
      expect(response.parsed_body.dig("viewer", "can_vote")).to eq(true)
      expect(response.parsed_body.dig("viewer", "can_review")).to eq(true)
    end
  end

  describe "POST /crimson-server-list/servers/:id/vote" do
    it "allows only one vote per user and calendar day" do
      server = create_server(owner: owner)
      path = "/crimson-server-list/servers/#{server.id}/vote.json"
      expect_route(path, method: :post, action: "vote", id: server.id)
      sign_in(member)

      post path
      expect_status(200)

      post path
      expect_status(422)

      expect(
        CrimsonServerList::Vote.where(
          server_id: server.id,
          user_id: member.id,
          voted_on: Time.zone.today,
        ).count,
      ).to eq(1)
      expect(server.reload.vote_count).to eq(1)
    end

    it "does not let a listing owner vote for their own server" do
      server = create_server(owner: owner)
      sign_in(owner)

      expect do
        post "/crimson-server-list/servers/#{server.id}/vote.json"
      end.not_to change(CrimsonServerList::Vote, :count)

      expect_status(422)
      expect(server.reload.vote_count).to eq(0)
    end
  end

  describe "PUT /crimson-server-list/servers/:id/review" do
    it "updates the member's existing review instead of creating duplicates" do
      server = create_server(owner: owner)
      path = "/crimson-server-list/servers/#{server.id}/review.json"
      expect_route(path, method: :put, action: "upsert_review", id: server.id)
      sign_in(member)

      put path, params: { rating: 5, body: "Excellent community." }
      expect_status(200)

      put path, params: { rating: 3, body: "Updated after another visit." }
      expect_status(200)

      reviews = CrimsonServerList::Review.where(server_id: server.id, user_id: member.id)
      expect(reviews.count).to eq(1)
      expect(reviews.first.rating).to eq(3)
      expect(reviews.first.body).to eq("Updated after another visit.")
      expect(server.reload.review_count).to eq(1)
      expect(server.rating_sum).to eq(3)
    end

    it "does not let a listing owner review their own server" do
      server = create_server(owner: owner)
      sign_in(owner)

      expect do
        put "/crimson-server-list/servers/#{server.id}/review.json",
            params: { rating: 5, body: "Self promotion" }
      end.not_to change(CrimsonServerList::Review, :count)

      expect_status(422)
      expect(server.reload.review_count).to eq(0)
      expect(server.rating_sum).to eq(0)
    end
  end

  describe "POST /crimson-server-list/servers/:id/claim" do
    it "keeps ownership unchanged until an admin approves the claim" do
      server = create_server(owner: owner)
      path = "/crimson-server-list/servers/#{server.id}/claim.json"
      expect_route(path, method: :post, action: "request_claim", id: server.id)
      sign_in(claimant)

      post path, params: { note: "I run this server." }

      expect_status(201)
      claim = CrimsonServerList::ClaimRequest.find_by!(server_id: server.id, requester_id: claimant.id)
      expect(claim.status).to eq("pending")
      expect(server.reload.owner_id).to eq(owner.id)

      sign_in(member)
      put "/crimson-server-list/admin/claims/#{claim.id}.json", params: { status: "approved" }
      expect_status(403)
      expect(server.reload.owner_id).to eq(owner.id)
      expect(claim.reload.status).to eq("pending")

      sign_in(admin)
      put "/crimson-server-list/admin/claims/#{claim.id}.json", params: { status: "approved" }

      expect_status(200)
      expect(server.reload.owner_id).to eq(claimant.id)
      expect(claim.reload.status).to eq("approved")
      expect(claim.reviewed_by_id).to eq(admin.id)
      expect(claim.reviewed_at).to be_present
    end
  end
end
