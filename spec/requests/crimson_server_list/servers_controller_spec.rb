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
    CrimsonServerList::Server.create!(
      **server_attributes(name: name),
      owner: owner,
      approved: true,
      enabled: true,
      status: "online",
      players_online: 12,
      players_max: 100,
    )
  end

  describe "POST /crimson-server-list/servers" do
    it "requires a signed-in user" do
      expect do
        post "/crimson-server-list/servers.json", params: server_attributes
      end.not_to change(CrimsonServerList::Server, :count)

      expect(response.status).to eq(403)
    end

    it "derives ownership and approval state on the server" do
      sign_in(member)

      expect do
        post "/crimson-server-list/servers.json",
             params: server_attributes.merge(owner_id: owner.id, approved: true)
      end.to change(CrimsonServerList::Server, :count).by(1)

      expect(response.status).to eq(201)
      server = CrimsonServerList::Server.order(:id).last
      expect(server.owner_id).to eq(member.id)
      expect(server.approved).to eq(false)
    end
  end

  describe "PUT /crimson-server-list/servers/:id" do
    it "does not let another member edit someone else's server" do
      server = create_server(owner: owner)
      sign_in(member)

      put "/crimson-server-list/servers/#{server.id}.json", params: { name: "Hijacked" }

      expect(response.status).to eq(403)
      expect(server.reload.name).to eq("Crimson Published Server")
    end
  end

  describe "POST /crimson-server-list/servers/:id/vote" do
    it "allows only one vote per user and calendar day" do
      server = create_server(owner: owner)
      sign_in(member)

      post "/crimson-server-list/servers/#{server.id}/vote.json"
      expect(response.status).to eq(200)

      post "/crimson-server-list/servers/#{server.id}/vote.json"
      expect(response.status).to eq(422)

      expect(
        CrimsonServerList::Vote.where(
          server_id: server.id,
          user_id: member.id,
          voted_on: Time.zone.today,
        ).count,
      ).to eq(1)
      expect(server.reload.vote_count).to eq(1)
    end
  end

  describe "PUT /crimson-server-list/servers/:id/review" do
    it "updates the member's existing review instead of creating duplicates" do
      server = create_server(owner: owner)
      sign_in(member)

      put "/crimson-server-list/servers/#{server.id}/review.json",
          params: { rating: 5, body: "Excellent community." }
      expect(response.status).to eq(200)

      put "/crimson-server-list/servers/#{server.id}/review.json",
          params: { rating: 3, body: "Updated after another visit." }
      expect(response.status).to eq(200)

      reviews = CrimsonServerList::Review.where(server_id: server.id, user_id: member.id)
      expect(reviews.count).to eq(1)
      expect(reviews.first.rating).to eq(3)
      expect(reviews.first.body).to eq("Updated after another visit.")
      expect(server.reload.review_count).to eq(1)
      expect(server.rating_sum).to eq(3)
    end
  end

  describe "POST /crimson-server-list/servers/:id/claim" do
    it "keeps ownership unchanged until an admin approves the claim" do
      server = create_server(owner: owner)
      sign_in(claimant)

      post "/crimson-server-list/servers/#{server.id}/claim.json", params: { note: "I run this server." }

      expect(response.status).to eq(201)
      claim = CrimsonServerList::ClaimRequest.find_by!(server_id: server.id, requester_id: claimant.id)
      expect(claim.status).to eq("pending")
      expect(server.reload.owner_id).to eq(owner.id)

      sign_in(member)
      put "/crimson-server-list/admin/claims/#{claim.id}.json", params: { status: "approved" }
      expect(response.status).to eq(403)
      expect(server.reload.owner_id).to eq(owner.id)
      expect(claim.reload.status).to eq("pending")

      sign_in(admin)
      put "/crimson-server-list/admin/claims/#{claim.id}.json", params: { status: "approved" }

      expect(response.status).to eq(200)
      expect(server.reload.owner_id).to eq(claimant.id)
      expect(claim.reload.status).to eq("approved")
      expect(claim.reviewed_by_id).to eq(admin.id)
      expect(claim.reviewed_at).to be_present
    end
  end
end
