# frozen_string_literal: true

RSpec.describe CrimsonServerList::FollowsController do
  let!(:owner) { Fabricate(:user) }
  let!(:member) { Fabricate(:user) }
  let!(:other_member) { Fabricate(:user) }

  before do
    SiteSetting.crimson_server_list_enabled = true
    SiteSetting.crimson_server_list_follows_enabled = true
  end

  def create_server(owner: self.owner, approved: true, enabled: true, name: "Follow API Server")
    CrimsonServerList::Server.create!(
      owner: owner,
      game_slug: "minecraft",
      name: name,
      short_description: "Favorites request-spec fixture.",
      host: "play-#{SecureRandom.hex(3)}.example.net",
      port: 25_565,
      approved: approved,
      enabled: enabled,
      status: "online",
      players_online: 2,
      players_max: 20,
      tags: [],
      game_details: {},
    )
  end

  def json_body
    response.parsed_body.with_indifferent_access
  end

  def follow_path(server)
    "/crimson-server-list/servers/#{server.id}/follow.json"
  end

  it "requires login for the private favorites list and follow mutations" do
    server = create_server

    get "/crimson-server-list/me/follows.json"
    expect(response.status).to eq(403)

    put follow_path(server)
    expect(response.status).to eq(403)
    expect(CrimsonServerList::Follow.count).to eq(0)
  end

  it "adds a published server to favorites with notifications disabled by default" do
    server = create_server
    sign_in(member)

    put follow_path(server)

    expect(response.status).to eq(201)
    follow = CrimsonServerList::Follow.last
    expect(follow.user_id).to eq(member.id)
    expect(follow.server_id).to eq(server.id)
    expect(follow.notifications_enabled).to eq(false)
    expect(json_body[:favorited]).to eq(true)
    expect(json_body[:notifications_enabled]).to eq(false)
  end

  it "is idempotent and updates notification preference without duplicate rows" do
    server = create_server
    sign_in(member)

    put follow_path(server)
    expect(response.status).to eq(201)

    put follow_path(server), params: { notifications_enabled: true }
    expect(response.status).to eq(200)
    expect(CrimsonServerList::Follow.where(user: member, server: server).count).to eq(1)
    expect(CrimsonServerList::Follow.find_by!(user: member, server: server).notifications_enabled).to eq(true)
    expect(json_body[:notifications_enabled]).to eq(true)

    put follow_path(server), params: { notifications_enabled: true }
    expect(response.status).to eq(200)
    expect(CrimsonServerList::Follow.where(user: member, server: server).count).to eq(1)
  end

  it "returns follow state only for the signed-in user" do
    server = create_server
    CrimsonServerList::Follow.create!(server: server, user: member, notifications_enabled: true)

    sign_in(other_member)
    get follow_path(server)

    expect(response.status).to eq(200)
    expect(json_body[:favorited]).to eq(false)
    expect(json_body[:notifications_enabled]).to eq(false)
  end

  it "keeps the private favorites list user-scoped and exposes only safe server fields" do
    mine = create_server(name: "My Saved Server")
    theirs = create_server(name: "Their Saved Server")
    CrimsonServerList::Follow.create!(server: mine, user: member)
    CrimsonServerList::Follow.create!(server: theirs, user: other_member)
    sign_in(member)

    get "/crimson-server-list/me/follows.json"

    expect(response.status).to eq(200)
    follows = json_body[:follows]
    expect(follows.map { |follow| follow.dig(:server, :id) }).to eq([mine.id])
    expect(response.body).not_to include(theirs.name)
    expect(follows.first.dig(:server, :host)).to be_nil
    expect(follows.first.dig(:server, :port)).to be_nil
  end

  it "does not expose unpublished or disabled followed listings through the private list" do
    hidden = create_server(approved: false, name: "Hidden Saved Server")
    disabled = create_server(enabled: false, name: "Disabled Saved Server")
    visible = create_server(name: "Visible Saved Server")
    CrimsonServerList::Follow.create!(server: hidden, user: member)
    CrimsonServerList::Follow.create!(server: disabled, user: member)
    CrimsonServerList::Follow.create!(server: visible, user: member)
    sign_in(member)

    get "/crimson-server-list/me/follows.json"

    expect(response.status).to eq(200)
    expect(json_body[:follows].map { |follow| follow.dig(:server, :id) }).to eq([visible.id])
    expect(response.body).not_to include(hidden.name)
    expect(response.body).not_to include(disabled.name)
  end

  it "does not allow creating favorites for unpublished or disabled listings" do
    hidden = create_server(approved: false, name: "Hidden Follow Target")
    disabled = create_server(enabled: false, name: "Disabled Follow Target")
    sign_in(member)

    put follow_path(hidden)
    expect(response.status).to eq(404)

    put follow_path(disabled)
    expect(response.status).to eq(404)

    expect(CrimsonServerList::Follow.count).to eq(0)
  end

  it "lets a user remove a favorite even after the listing becomes hidden" do
    server = create_server
    follow = CrimsonServerList::Follow.create!(server: server, user: member)
    server.update!(approved: false)
    sign_in(member)

    delete follow_path(server)

    expect(response.status).to eq(200)
    expect(json_body[:favorited]).to eq(false)
    expect(CrimsonServerList::Follow.exists?(follow.id)).to eq(false)
  end

  it "honors the follows feature toggle" do
    server = create_server
    SiteSetting.crimson_server_list_follows_enabled = false
    sign_in(member)

    get "/crimson-server-list/me/follows.json"
    expect(response.status).to eq(403)

    put follow_path(server)
    expect(response.status).to eq(403)
    expect(CrimsonServerList::Follow.count).to eq(0)
  end

  it "enforces the per-user saved-server cap before creating another row" do
    existing_server = create_server(name: "Existing Favorite")
    another_server = create_server(name: "Favorite Over Limit")
    CrimsonServerList::Follow.create!(server: existing_server, user: member)
    sign_in(member)

    stub_const(CrimsonServerList::FollowsController, :MAX_FOLLOWS_PER_USER, 1) do
      put follow_path(another_server)

      expect(response.status).to eq(422)
      expect(CrimsonServerList::Follow.where(user: member).count).to eq(1)
    end
  end
end
