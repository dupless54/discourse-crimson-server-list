# frozen_string_literal: true

RSpec.describe CrimsonServerList::OwnedServersController do
  let!(:owner) { Fabricate(:user) }
  let!(:other_owner) { Fabricate(:user) }
  let!(:admin) { Fabricate(:admin) }

  before do
    SiteSetting.crimson_server_list_enabled = true
    SiteSetting.crimson_server_list_live_query_enabled = true
    SiteSetting.crimson_server_list_owner_edits_require_approval = true
  end

  def create_server(
    owner:,
    name:,
    approved: true,
    enabled: true,
    status: "online",
    monitoring_enabled: true,
    host: nil
  )
    CrimsonServerList::Server.create!(
      owner: owner,
      game_slug: "minecraft",
      name: name,
      short_description: "Owner dashboard request-spec fixture.",
      description: "Private owner dashboard fixture data.",
      host: host || "#{name.parameterize}.example.net",
      port: 25_565,
      approved: approved,
      enabled: enabled,
      status: status,
      monitoring_enabled: monitoring_enabled,
      players_online: status == "online" ? 4 : 0,
      players_max: 20,
      tags: %w[owner-panel],
      game_details: { edition: "Java" },
    )
  end

  def json_body
    response.parsed_body.with_indifferent_access
  end

  it "requires login and keeps the response private" do
    get "/crimson-server-list/me/servers.json"
    expect(response.status).to eq(403)

    sign_in(owner)
    get "/crimson-server-list/me/servers.json"

    expect(response.status).to eq(200)
    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  it "returns only the signed-in owner's servers including pending and disabled listings" do
    published = create_server(owner: owner, name: "Published Mine")
    pending = create_server(owner: owner, name: "Pending Mine", approved: false)
    disabled = create_server(owner: owner, name: "Disabled Mine", enabled: false)
    theirs = create_server(owner: other_owner, name: "Someone Else Server", host: "private-other.example.net")
    sign_in(owner)

    get "/crimson-server-list/me/servers.json"

    expect(response.status).to eq(200)
    servers = json_body[:servers]
    expect(servers.map { |server| server[:id] }.sort).to eq([published.id, pending.id, disabled.id].sort)
    expect(response.body).not_to include(theirs.name)
    expect(response.body).not_to include(theirs.host)

    states = servers.index_by { |server| server[:id] }
    expect(states.dig(published.id, :management, :publication_state)).to eq("published")
    expect(states.dig(pending.id, :management, :publication_state)).to eq("pending")
    expect(states.dig(disabled.id, :management, :publication_state)).to eq("disabled")
  end

  it "exposes owner-only management fields and server-authoritative action state" do
    refreshable = create_server(owner: owner, name: "Refreshable Mine", host: "owner-secret.example.net")
    pending = create_server(owner: owner, name: "Pending Refresh", approved: false)
    sign_in(owner)

    get "/crimson-server-list/me/servers.json"

    expect(response.status).to eq(200)
    servers = json_body[:servers].index_by { |server| server[:id] }

    expect(servers.dig(refreshable.id, :host)).to eq("owner-secret.example.net")
    expect(servers.dig(refreshable.id, :port)).to eq(25_565)
    expect(servers.dig(refreshable.id, :management, :can_edit)).to eq(true)
    expect(servers.dig(refreshable.id, :management, :can_refresh)).to eq(true)
    expect(servers.dig(refreshable.id, :management, :edit_requires_approval)).to eq(true)
    expect(servers.dig(pending.id, :management, :can_refresh)).to eq(false)
  end

  it "returns aggregate owner stats across all owned publication states" do
    verified = create_server(owner: owner, name: "Verified Mine")
    verified.update_columns(verified_at: Time.zone.now)
    create_server(owner: owner, name: "Pending Mine", approved: false, status: "unknown")
    create_server(owner: owner, name: "Disabled Mine", enabled: false, status: "offline", monitoring_enabled: false)
    create_server(owner: other_owner, name: "Other Online")
    sign_in(owner)

    get "/crimson-server-list/me/servers.json"

    expect(response.status).to eq(200)
    expect(json_body[:stats]).to include(
      total: 3,
      published: 1,
      pending: 1,
      disabled: 1,
      online: 1,
      monitored: 2,
      verified: 1,
    )
  end

  it "keeps admin access scoped to the admin's own servers" do
    mine = create_server(owner: admin, name: "Admin Owned")
    theirs = create_server(owner: owner, name: "User Owned", host: "user-private.example.net")
    sign_in(admin)

    get "/crimson-server-list/me/servers.json"

    expect(response.status).to eq(200)
    expect(json_body[:servers].map { |server| server[:id] }).to eq([mine.id])
    expect(response.body).not_to include(theirs.name)
    expect(response.body).not_to include(theirs.host)
    expect(json_body.dig(:servers, 0, :management, :edit_requires_approval)).to eq(false)
  end

  it "bounds pagination parameters and reports authoritative totals" do
    first = create_server(owner: owner, name: "First Mine")
    second = create_server(owner: owner, name: "Second Mine")
    first.update_columns(updated_at: 2.minutes.ago)
    second.update_columns(updated_at: 1.minute.ago)
    sign_in(owner)

    get "/crimson-server-list/me/servers.json", params: { page: 1, per_page: 1 }

    expect(response.status).to eq(200)
    expect(json_body[:servers].map { |server| server[:id] }).to eq([second.id])
    expect(json_body[:pagination]).to include(
      page: 1,
      per_page: 1,
      total: 2,
      total_pages: 2,
      has_more: true,
    )

    get "/crimson-server-list/me/servers.json", params: { page: 999, per_page: 999 }

    expect(response.status).to eq(200)
    expect(json_body[:servers]).to eq([])
    expect(json_body[:pagination]).to include(page: 200, per_page: 50, total: 2, total_pages: 1, has_more: false)
  end

  it "honors the plugin enabled boundary" do
    SiteSetting.crimson_server_list_enabled = false
    sign_in(owner)

    get "/crimson-server-list/me/servers.json"

    expect(response.status).to eq(404)
  end
end
