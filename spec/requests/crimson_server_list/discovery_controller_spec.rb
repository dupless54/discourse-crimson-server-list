# frozen_string_literal: true

RSpec.describe CrimsonServerList::DiscoveryController do
  let!(:owner) { Fabricate(:user) }
  let!(:member) { Fabricate(:user) }

  before { SiteSetting.crimson_server_list_enabled = true }

  def create_server(
    name:,
    game_slug: "minecraft",
    tags: %w[survival community],
    status: "online",
    approved: true,
    enabled: true,
    featured: false,
    vote_count: 0,
    players_online: 12,
    review_count: 0,
    rating_sum: 0
  )
    port = game_slug == "rust" ? 28_015 : 25_565
    CrimsonServerList::Server.create!(
      owner: owner,
      game_slug: game_slug,
      name: name,
      short_description: "Discovery fixture for #{name}.",
      host: "play.example.net",
      port: port,
      country_code: "TR",
      language: "tr",
      mode: "survival",
      version: "1.0",
      tags: tags,
      status: status,
      approved: approved,
      enabled: enabled,
      featured: featured,
      vote_count: vote_count,
      players_online: players_online,
      players_max: 100,
      review_count: review_count,
      rating_sum: rating_sum,
    )
  end

  def get_discovery(params = {})
    get "/crimson-server-list/discovery.json", params: params
    expect(response.status).to eq(200), response.body
    response.parsed_body
  end

  it "routes to the isolated discovery controller" do
    route =
      Rails.application.routes.recognize_path(
        "/crimson-server-list/discovery.json",
        method: :get,
      )

    expect(route[:controller]).to eq("crimson_server_list/discovery")
    expect(route[:action]).to eq("index")
    expect(route[:format]).to eq("json")
  end

  it "filters the public catalogue before pagination" do
    target =
      create_server(
        name: "Crimson Survival",
        tags: %w[survival trusted],
        status: "online",
      )
    target.update_columns(verified_at: 1.day.ago)
    create_server(name: "Crimson PvP", tags: %w[pvp], status: "online")
    create_server(name: "Rust Survival", game_slug: "rust", tags: %w[survival])
    create_server(name: "Hidden Survival", tags: %w[survival], approved: false)
    create_server(name: "Disabled Survival", tags: %w[survival], enabled: false)

    body =
      get_discovery(
        game: "minecraft",
        tag: "survival",
        status: "online",
        verified: "true",
        q: "Crimson Survival",
        per_page: 10,
      )

    expect(body["servers"].map { |server| server["id"] }).to eq([target.id])
    expect(body.dig("pagination", "total")).to eq(1)
    expect(body["filters"]).to include(
      "game" => "minecraft",
      "tag" => "survival",
      "status" => "online",
      "verified" => true,
      "q" => "Crimson Survival",
      "sort" => "top",
    )
  end

  it "paginates deterministically after sorting" do
    servers =
      5.times.map do |index|
        server = create_server(name: "Newest #{index}")
        server.update_columns(created_at: index.days.ago, updated_at: index.days.ago)
        server
      end

    body = get_discovery(sort: "new", page: 2, per_page: 2)

    expect(body["servers"].map { |server| server["id"] }).to eq(
      [servers[2].id, servers[3].id],
    )
    expect(body["pagination"]).to eq(
      "page" => 2,
      "per_page" => 2,
      "total" => 5,
      "total_pages" => 3,
      "has_more" => true,
    )
  end

  it "treats SQL wildcard characters in search as literal text" do
    create_server(name: "Ordinary Server")

    percent_body = get_discovery(q: "%")
    underscore_body = get_discovery(q: "_")

    expect(percent_body.dig("pagination", "total")).to eq(0)
    expect(underscore_body.dig("pagination", "total")).to eq(0)
  end

  it "bounds pagination and normalizes unsupported filters" do
    create_server(name: "Bounded Server")

    body =
      get_discovery(
        page: -5,
        per_page: 999,
        game: "not-a-game",
        status: "broken",
        verified: "maybe",
        sort: "random",
        q: "x" * 120,
      )

    expect(body.dig("pagination", "page")).to eq(1)
    expect(body.dig("pagination", "per_page")).to eq(50)
    expect(body["filters"]["game"]).to be_nil
    expect(body["filters"]["status"]).to be_nil
    expect(body["filters"]["verified"]).to be_nil
    expect(body["filters"]["sort"]).to eq("top")
    expect(body["filters"]["q"].length).to eq(80)
  end

  it "never exposes endpoint or probe diagnostics in discovery cards" do
    server = create_server(name: "Private Endpoint Server")
    sign_in(owner)

    body = get_discovery(q: "Private Endpoint Server")
    payload = body["servers"].find { |candidate| candidate["id"] == server.id }

    expect(payload).to be_present
    expect(payload.keys).not_to include(
      "host",
      "port",
      "query_port",
      "address",
      "query_adapter",
      "last_response_ms",
      "last_query_error",
    )
  end

  it "preserves the current user's daily vote state without exposing other users" do
    server = create_server(name: "Voted Server")
    CrimsonServerList::Vote.create!(
      server: server,
      user: member,
      voted_on: Time.zone.today,
    )
    sign_in(member)

    body = get_discovery(q: "Voted Server")

    expect(body["servers"].first["voted_today"]).to eq(true)
    expect(body["viewer"]["logged_in"]).to eq(true)
  end
end
