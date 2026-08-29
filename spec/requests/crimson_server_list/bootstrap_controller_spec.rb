# frozen_string_literal: true

RSpec.describe CrimsonServerList::BootstrapController do
  let!(:owner) { Fabricate(:user) }
  let!(:claimant) { Fabricate(:user) }
  let!(:admin) { Fabricate(:admin) }

  before do
    SiteSetting.crimson_server_list_enabled = true
    SiteSetting.crimson_server_list_submission_enabled = true
    SiteSetting.crimson_server_list_votes_enabled = true
    SiteSetting.crimson_server_list_reviews_enabled = true
  end

  def create_server(name:, approved: true, enabled: true, tags: %w[survival community])
    CrimsonServerList::Server.create!(
      owner: owner,
      game_slug: "minecraft",
      name: name,
      short_description: "Bootstrap request spec server.",
      description: "Stable fixture data.",
      host: "play.example.net",
      port: 25_565,
      approved: approved,
      enabled: enabled,
      status: "online",
      players_online: 12,
      players_max: 100,
      vote_count: 5,
      review_count: 2,
      rating_sum: 8,
      tags: tags,
    )
  end

  it "routes the metadata bootstrap independently from the catalogue endpoint" do
    route =
      Rails.application.routes.recognize_path(
        "/crimson-server-list/bootstrap.json",
        method: :get,
      )

    expect(route[:controller]).to eq("crimson_server_list/bootstrap")
    expect(route[:action]).to eq("index")
    expect(route[:format]).to eq("json")
  end

  it "returns public metadata without serializing catalogue cards" do
    published = create_server(name: "Published Bootstrap Server")
    create_server(name: "Pending Bootstrap Server", approved: false)

    get "/crimson-server-list/bootstrap.json"

    expect(response.status).to eq(200)
    payload = response.parsed_body
    minecraft = payload.fetch("games").find { |game| game["slug"] == "minecraft" }
    survival = payload.fetch("tags").find { |tag| tag["slug"] == "survival" }

    expect(payload).not_to have_key("servers")
    expect(minecraft.fetch("server_count")).to eq(1)
    expect(survival.fetch("server_count")).to eq(1)
    expect(payload.dig("stats", "server_count")).to eq(1)
    expect(payload.dig("stats", "vote_count")).to eq(5)
    expect(payload.dig("stats", "online_count")).to eq(1)
    expect(payload.dig("stats", "review_count")).to eq(2)
    expect(payload.dig("viewer", "logged_in")).to eq(false)
    expect(response.headers["Cache-Control"]).to include("private", "no-store")

    get "/crimson-server-list.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body.fetch("servers").map { |server| server["id"] }).to include(published.id)
  end

  it "keeps admin moderation queues in the slim bootstrap" do
    published = create_server(name: "Claimed Bootstrap Server")
    pending = create_server(name: "Pending Admin Server", approved: false)
    claim =
      CrimsonServerList::ClaimRequest.create!(
        server: published,
        requester: claimant,
        note: "I manage this server.",
      )

    sign_in(admin)
    get "/crimson-server-list/bootstrap.json"

    expect(response.status).to eq(200)
    payload = response.parsed_body

    expect(payload).not_to have_key("servers")
    expect(payload.fetch("pending_servers").map { |server| server["id"] }).to include(pending.id)
    expect(payload.fetch("pending_claims").map { |item| item["id"] }).to include(claim.id)
  end
end
