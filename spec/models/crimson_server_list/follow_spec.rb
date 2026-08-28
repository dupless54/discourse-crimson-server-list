# frozen_string_literal: true

RSpec.describe CrimsonServerList::Follow do
  let!(:owner) { Fabricate(:user) }
  let!(:member) { Fabricate(:user) }

  def create_server
    CrimsonServerList::Server.create!(
      owner: owner,
      game_slug: "minecraft",
      name: "Follow Model Server",
      short_description: "Follow model fixture.",
      host: "follow-model-#{SecureRandom.hex(3)}.example.net",
      port: 25_565,
      approved: true,
      enabled: true,
      status: "online",
      players_online: 1,
      players_max: 10,
      tags: [],
      game_details: {},
    )
  end

  it "enforces one follow row per user and server at the database level" do
    server = create_server
    CrimsonServerList::Follow.create!(server: server, user: member)

    expect do
      CrimsonServerList::Follow.insert_all!(
        [
          {
            server_id: server.id,
            user_id: member.id,
            notifications_enabled: false,
            created_at: Time.zone.now,
            updated_at: Time.zone.now,
          },
        ],
      )
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "removes follow rows when the server listing is deleted" do
    server = create_server
    CrimsonServerList::Follow.create!(server: server, user: member)

    expect { server.destroy! }.to change { CrimsonServerList::Follow.count }.from(1).to(0)
  end
end
