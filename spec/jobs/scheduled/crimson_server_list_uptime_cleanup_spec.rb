# frozen_string_literal: true

RSpec.describe Jobs::CrimsonServerListUptimeCleanup do
  let!(:owner) { Fabricate(:user) }
  let!(:server) do
    CrimsonServerList::Server.create!(
      game_slug: "minecraft",
      name: "Cleanup History Server",
      short_description: "Retention cleanup fixture.",
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
    SiteSetting.crimson_server_list_uptime_history_retention_days = 30
  end

  it "deletes expired samples while keeping samples inside retention" do
    expired =
      CrimsonServerList::UptimeSample.create!(
        server: server,
        sampled_at: 31.days.ago,
        status: "online",
        supports_player_count: false,
      )
    retained =
      CrimsonServerList::UptimeSample.create!(
        server: server,
        sampled_at: 29.days.ago,
        status: "offline",
        supports_player_count: false,
      )

    described_class.new.execute({})

    expect(CrimsonServerList::UptimeSample.exists?(expired.id)).to eq(false)
    expect(CrimsonServerList::UptimeSample.exists?(retained.id)).to eq(true)
  end
end
