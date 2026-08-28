# frozen_string_literal: true

RSpec.describe Jobs::CrimsonServerListFollowNotification do
  let!(:owner) { Fabricate(:user) }
  let!(:follower) { Fabricate(:user) }
  let!(:server) do
    CrimsonServerList::Server.create!(
      game_slug: "minecraft",
      name: "Notification Server",
      short_description: "Notification delivery fixture.",
      host: "notify.example.net",
      port: 25_565,
      owner: owner,
      approved: true,
      enabled: true,
      monitoring_enabled: true,
      status: "online",
    )
  end

  before do
    SiteSetting.crimson_server_list_enabled = true
    SiteSetting.crimson_server_list_follows_enabled = true
  end

  it "creates one durable back-online notification for an opted-in follower" do
    follow =
      CrimsonServerList::Follow.create!(
        server: server,
        user: follower,
        notifications_enabled: true,
      )
    transition_at = 2.minutes.ago.change(usec: 0)

    expect do
      described_class.new.execute(
        server_id: server.id,
        event: "back_online",
        transition_at: transition_at.iso8601,
      )
    end.to change {
      Notification.where(
        user_id: follower.id,
        notification_type: Notification.types[:crimson_server_back_online],
      ).count
    }.by(1)

    notification = Notification.where(user_id: follower.id).order(:id).last
    expect(notification.data_hash[:server_id]).to eq(server.id)
    expect(notification.data_hash[:server_name]).to eq(server.name)
    expect(notification.data_hash[:detail_url]).to eq("/servers/#{server.slug}")
    expect(notification.data_hash[:event]).to eq("back_online")
    expect(follow.reload.last_online_notification_at).to eq_time(transition_at)
  end

  it "does not duplicate a notification when the same transition job retries" do
    CrimsonServerList::Follow.create!(
      server: server,
      user: follower,
      notifications_enabled: true,
    )
    transition_at = 3.minutes.ago.change(usec: 0)
    args = {
      server_id: server.id,
      event: "back_online",
      transition_at: transition_at.iso8601,
    }

    described_class.new.execute(args)
    described_class.new.execute(args)

    expect(
      Notification.where(
        user_id: follower.id,
        notification_type: Notification.types[:crimson_server_back_online],
      ).count,
    ).to eq(1)
  end

  it "does not notify followers that did not enable notifications" do
    CrimsonServerList::Follow.create!(
      server: server,
      user: follower,
      notifications_enabled: false,
    )

    expect do
      described_class.new.execute(
        server_id: server.id,
        event: "back_online",
        transition_at: Time.zone.now.iso8601,
      )
    end.not_to change { Notification.where(user_id: follower.id).count }
  end

  it "suppresses a stale back-online job when the server is no longer online" do
    CrimsonServerList::Follow.create!(
      server: server,
      user: follower,
      notifications_enabled: true,
    )
    server.update_columns(status: "offline")

    expect do
      described_class.new.execute(
        server_id: server.id,
        event: "back_online",
        transition_at: Time.zone.now.iso8601,
      )
    end.not_to change { Notification.where(user_id: follower.id).count }
  end

  it "continues large fan-out in bounded batches" do
    second_follower = Fabricate(:user)
    first_follow =
      CrimsonServerList::Follow.create!(
        server: server,
        user: follower,
        notifications_enabled: true,
      )
    CrimsonServerList::Follow.create!(
      server: server,
      user: second_follower,
      notifications_enabled: true,
    )
    transition_at = Time.zone.now.change(usec: 0)
    enqueued = []
    allow(Jobs).to receive(:enqueue) do |job_name, **args|
      enqueued << [job_name, args]
    end

    stub_const(described_class, :BATCH_SIZE, 1) do
      described_class.new.execute(
        server_id: server.id,
        event: "back_online",
        transition_at: transition_at.iso8601,
      )
    end

    expect(enqueued).to eq(
      [
        [
          :crimson_server_list_follow_notification,
          {
            server_id: server.id,
            event: "back_online",
            transition_at: transition_at.iso8601,
            after_id: first_follow.id,
          },
        ],
      ],
    )
  end
end
