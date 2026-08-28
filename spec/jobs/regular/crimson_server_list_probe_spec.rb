# frozen_string_literal: true

RSpec.describe Jobs::CrimsonServerListProbe do
  let!(:owner) { Fabricate(:user) }
  let!(:server) do
    CrimsonServerList::Server.create!(
      game_slug: "minecraft",
      name: "Probe History Server",
      short_description: "Probe history fixture.",
      host: "play.example.net",
      port: 25_565,
      owner: owner,
      approved: true,
      enabled: true,
      monitoring_enabled: true,
      status: "unknown",
    )
  end

  before do
    SiteSetting.crimson_server_list_enabled = true
    SiteSetting.crimson_server_list_live_query_enabled = true
    SiteSetting.crimson_server_list_uptime_history_enabled = true
    SiteSetting.crimson_server_list_follows_enabled = true
    allow(CrimsonServerList::ProbeService).to receive(:write_cache)
  end

  it "records successful player-count probes" do
    result =
      CrimsonServerList::ProbeResult.new(
        status: "online",
        players_online: 15,
        players_max: 100,
        adapter: "minecraft-java",
        supports_player_count: true,
      )
    allow(CrimsonServerList::ProbeService).to receive(:call).and_return([result, 41])

    described_class.new.execute(server_id: server.id, force: true)

    sample = CrimsonServerList::UptimeSample.find_by!(server_id: server.id)
    expect(sample.status).to eq("online")
    expect(sample.response_ms).to eq(41)
    expect(sample.supports_player_count).to eq(true)
    expect(sample.players_online).to eq(15)
    expect(sample.players_max).to eq(100)
  end

  it "records failure status without fabricated player counts" do
    allow(CrimsonServerList::ProbeService).to receive(:call).and_raise(Timeout::Error, "timeout")

    described_class.new.execute(server_id: server.id, force: true)

    sample = CrimsonServerList::UptimeSample.find_by!(server_id: server.id)
    expect(sample.status).to eq("offline")
    expect(sample.supports_player_count).to eq(false)
    expect(sample.players_online).to be_nil
    expect(sample.players_max).to be_nil
  end

  it "enqueues follower delivery only when an offline server comes back online" do
    server.update_columns(status: "offline")
    result =
      CrimsonServerList::ProbeResult.new(
        status: "online",
        players_online: 0,
        players_max: 0,
        adapter: "minecraft-java",
        supports_player_count: true,
      )
    allow(CrimsonServerList::ProbeService).to receive(:call).and_return([result, 20])
    enqueued = []
    allow(Jobs).to receive(:enqueue) do |job_name, **args|
      enqueued << [job_name, args]
    end

    described_class.new.execute(server_id: server.id, force: true)

    expect(enqueued.length).to eq(1)
    job_name, args = enqueued.first
    expect(job_name).to eq(:crimson_server_list_follow_notification)
    expect(args[:server_id]).to eq(server.id)
    expect(args[:event]).to eq("back_online")
    expect(Time.zone.parse(args[:transition_at])).to be_present
  end

  it "does not enqueue follower delivery for unknown-to-online probes" do
    result =
      CrimsonServerList::ProbeResult.new(
        status: "online",
        players_online: 0,
        players_max: 0,
        adapter: "minecraft-java",
        supports_player_count: true,
      )
    allow(CrimsonServerList::ProbeService).to receive(:call).and_return([result, 20])
    allow(Jobs).to receive(:enqueue)

    described_class.new.execute(server_id: server.id, force: true)

    expect(Jobs).not_to have_received(:enqueue).with(
      :crimson_server_list_follow_notification,
      anything,
    )
  end

  it "keeps the successful probe state when notification enqueue fails" do
    server.update_columns(status: "offline")
    result =
      CrimsonServerList::ProbeResult.new(
        status: "online",
        players_online: 2,
        players_max: 10,
        adapter: "minecraft-java",
        supports_player_count: true,
      )
    allow(CrimsonServerList::ProbeService).to receive(:call).and_return([result, 22])
    allow(Jobs).to receive(:enqueue).and_raise(StandardError, "queue unavailable")
    allow(Rails.logger).to receive(:warn)

    described_class.new.execute(server_id: server.id, force: true)

    expect(server.reload.status).to eq("online")
    expect(server.players_online).to eq(2)
    expect(Rails.logger).to have_received(:warn).with(
      a_string_including("follow notification enqueue failed"),
    )
  end
end
