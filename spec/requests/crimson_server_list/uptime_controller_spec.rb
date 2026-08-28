# frozen_string_literal: true

RSpec.describe CrimsonServerList::UptimeController do
  let!(:owner) { Fabricate(:user) }

  before do
    SiteSetting.crimson_server_list_enabled = true
    SiteSetting.crimson_server_list_uptime_history_enabled = true
  end

  def create_server(name:, approved: true, enabled: true)
    CrimsonServerList::Server.create!(
      game_slug: "minecraft",
      name: name,
      short_description: "Uptime API fixture.",
      host: "play.example.net",
      port: 25_565,
      owner: owner,
      approved: approved,
      enabled: enabled,
      status: "online",
    )
  end

  it "returns bounded public history for a published server" do
    server = create_server(name: "Published Uptime Server")
    now = Time.zone.now
    CrimsonServerList::UptimeSample.create!(
      server: server,
      sampled_at: 20.minutes.ago(now),
      status: "online",
      response_ms: 45,
      supports_player_count: true,
      players_online: 12,
      players_max: 100,
    )
    CrimsonServerList::UptimeSample.create!(
      server: server,
      sampled_at: 10.minutes.ago(now),
      status: "offline",
      supports_player_count: false,
    )

    get "/crimson-server-list/servers/#{server.id}/uptime.json", params: { range: "24h" }

    expect(response.status).to eq(200)
    payload = response.parsed_body
    expect(payload.dig("server", "id")).to eq(server.id)
    expect(payload.dig("uptime", "range")).to eq("24h")
    expect(payload.dig("uptime", "sample_count")).to eq(2)
    expect(payload.dig("uptime", "known_sample_count")).to eq(2)
    expect(payload.dig("uptime", "uptime_percent")).to eq(50.0)
    expect(payload.dig("uptime", "series").length).to eq(2)
    expect(payload.dig("uptime", "series", 1, "players_online")).to be_nil
  end

  it "does not expose history for an unpublished server" do
    server = create_server(name: "Pending Uptime Server", approved: false)

    get "/crimson-server-list/servers/#{server.id}/uptime.json"

    expect(response.status).to eq(404)
  end

  it "returns not found while uptime history is disabled" do
    server = create_server(name: "Disabled History Server")
    SiteSetting.crimson_server_list_uptime_history_enabled = false

    get "/crimson-server-list/servers/#{server.id}/uptime.json"

    expect(response.status).to eq(404)
  end

  it "falls back to the 24 hour range for unsupported range values" do
    server = create_server(name: "Range Uptime Server")

    get "/crimson-server-list/servers/#{server.id}/uptime.json", params: { range: "forever" }

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("uptime", "range")).to eq("24h")
  end
end
