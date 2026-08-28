# frozen_string_literal: true

RSpec.describe CrimsonServerList::UptimeHistory do
  let!(:owner) { Fabricate(:user) }
  let!(:server) do
    CrimsonServerList::Server.create!(
      game_slug: "minecraft",
      name: "History Test Server",
      short_description: "Uptime history fixture.",
      host: "play.example.net",
      port: 25_565,
      owner: owner,
      approved: true,
      enabled: true,
      status: "online",
    )
  end

  before do
    SiteSetting.crimson_server_list_enabled = true
    SiteSetting.crimson_server_list_uptime_history_enabled = true
    SiteSetting.crimson_server_list_uptime_history_retention_days = 30
  end

  it "upserts one sample per server and ten-minute bucket" do
    first_time = Time.zone.parse("2026-08-29 10:01:00")
    second_time = Time.zone.parse("2026-08-29 10:09:59")

    described_class.record!(
      server: server,
      status: "online",
      checked_at: first_time,
      response_ms: 42,
      players_online: 12,
      players_max: 100,
      supports_player_count: true,
    )
    described_class.record!(
      server: server,
      status: "offline",
      checked_at: second_time,
      response_ms: nil,
      supports_player_count: false,
    )

    samples = CrimsonServerList::UptimeSample.where(server_id: server.id)
    expect(samples.count).to eq(1)
    sample = samples.first
    expect(sample.sampled_at).to eq(Time.utc(2026, 8, 29, 10, 0, 0))
    expect(sample.status).to eq("offline")
    expect(sample.players_online).to be_nil
    expect(sample.players_max).to be_nil
    expect(sample.supports_player_count).to eq(false)
  end

  it "does not store player counts when the adapter does not support them" do
    described_class.record!(
      server: server,
      status: "online",
      checked_at: Time.zone.now,
      players_online: 999,
      players_max: 999,
      supports_player_count: false,
    )

    sample = CrimsonServerList::UptimeSample.find_by!(server_id: server.id)
    expect(sample.players_online).to be_nil
    expect(sample.players_max).to be_nil
  end

  it "calculates uptime from online and offline samples only" do
    now = Time.zone.parse("2026-08-29 12:00:00")
    samples =
      [
        ["online", 50.minutes.ago(now)],
        ["online", 40.minutes.ago(now)],
        ["offline", 30.minutes.ago(now)],
        ["unknown", 20.minutes.ago(now)],
        ["maintenance", 10.minutes.ago(now)],
      ].map do |status, sampled_at|
        CrimsonServerList::UptimeSample.create!(
          server: server,
          sampled_at: sampled_at,
          status: status,
          supports_player_count: false,
        )
      end

    summary = described_class.summarize(samples, range: "24h", now: now)

    expect(summary[:sample_count]).to eq(5)
    expect(summary[:known_sample_count]).to eq(3)
    expect(summary[:online_sample_count]).to eq(2)
    expect(summary[:uptime_percent]).to eq(66.7)
  end

  it "returns nil uptime when no online or offline samples exist" do
    sample =
      CrimsonServerList::UptimeSample.create!(
        server: server,
        sampled_at: Time.zone.now,
        status: "unknown",
        supports_player_count: false,
      )

    summary = described_class.summarize([sample], range: "24h")

    expect(summary[:uptime_percent]).to be_nil
    expect(summary[:known_sample_count]).to eq(0)
  end

  it "clamps configured retention to the supported range" do
    SiteSetting.crimson_server_list_uptime_history_retention_days = 90
    expect(described_class.retention_days).to eq(90)
  end
end
