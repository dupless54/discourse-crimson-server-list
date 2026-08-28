# frozen_string_literal: true

RSpec.describe CrimsonServerList::ReportsController do
  let!(:owner) { Fabricate(:user) }
  let!(:member) { Fabricate(:user) }
  let!(:other_member) { Fabricate(:user) }
  let!(:admin) { Fabricate(:admin) }

  before do
    SiteSetting.crimson_server_list_enabled = true
    SiteSetting.crimson_server_list_reports_enabled = true
  end

  def create_server(owner: self.owner, approved: true, enabled: true, name: "Report API Server")
    CrimsonServerList::Server.create!(
      owner: owner,
      game_slug: "minecraft",
      name: name,
      short_description: "Reporting request-spec fixture.",
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

  def report_path(server)
    "/crimson-server-list/servers/#{server.id}/report.json"
  end

  it "requires login to report a published server" do
    server = create_server

    post report_path(server), params: { reason: "spam" }

    expect(response.status).to eq(403)
    expect(CrimsonServerList::Report.count).to eq(0)
  end

  it "creates a pending report without exposing reporter identity in the member response" do
    server = create_server
    sign_in(member)

    post report_path(server), params: { reason: "misleading", details: "Listing details are inaccurate." }

    expect(response.status).to eq(201)
    report = CrimsonServerList::Report.last
    expect(report.reporter_id).to eq(member.id)
    expect(report.server_id).to eq(server.id)
    expect(report.status).to eq("pending")
    expect(json_body.dig(:report, :reporter)).to be_nil
    expect(json_body.dig(:report, :server, :id)).to eq(server.id)
  end

  it "does not allow a listing owner to report their own server" do
    server = create_server
    sign_in(owner)

    post report_path(server), params: { reason: "spam" }

    expect(response.status).to eq(422)
    expect(CrimsonServerList::Report.count).to eq(0)
  end

  it "does not allow reports against unpublished or disabled listings" do
    hidden = create_server(approved: false, name: "Hidden Report Server")
    disabled = create_server(enabled: false, name: "Disabled Report Server")
    sign_in(member)

    post report_path(hidden), params: { reason: "spam" }
    expect(response.status).to eq(404)

    post report_path(disabled), params: { reason: "spam" }
    expect(response.status).to eq(404)

    expect(CrimsonServerList::Report.count).to eq(0)
  end

  it "rejects a second pending report from the same user for the same server" do
    server = create_server
    CrimsonServerList::Report.create!(server: server, reporter: member, reason: "spam")
    sign_in(member)

    post report_path(server), params: { reason: "unsafe", details: "Another reason." }

    expect(response.status).to eq(422)
    expect(CrimsonServerList::Report.where(server: server, reporter: member).count).to eq(1)
  end

  it "validates report reasons and requires details for other" do
    server = create_server
    sign_in(member)

    post report_path(server), params: { reason: "not-a-reason" }
    expect(response.status).to eq(422)

    Discourse.redis.del("crimson-server-list:report:create:#{member.id}:#{server.id}")
    post report_path(server), params: { reason: "other", details: "" }
    expect(response.status).to eq(422)

    expect(CrimsonServerList::Report.count).to eq(0)
  end

  it "honors the reporting feature toggle" do
    server = create_server
    SiteSetting.crimson_server_list_reports_enabled = false
    sign_in(member)

    post report_path(server), params: { reason: "spam" }

    expect(response.status).to eq(403)
    expect(CrimsonServerList::Report.count).to eq(0)
  end

  it "keeps the moderation queue admin-only and returns reporter identity only there" do
    server = create_server
    report = CrimsonServerList::Report.create!(server: server, reporter: member, reason: "spam")

    sign_in(other_member)
    get "/crimson-server-list/admin/reports.json"
    expect(response.status).to eq(403)

    sign_in(admin)
    get "/crimson-server-list/admin/reports.json"

    expect(response.status).to eq(200)
    payload = json_body[:reports]
    expect(payload.length).to eq(1)
    expect(payload.first[:id]).to eq(report.id)
    expect(payload.first.dig(:reporter, :id)).to eq(member.id)
    expect(payload.first.dig(:server, :id)).to eq(server.id)
  end

  it "lets an admin resolve a pending report without automatically changing the listing" do
    server = create_server
    report = CrimsonServerList::Report.create!(server: server, reporter: member, reason: "unsafe")
    sign_in(admin)

    put "/crimson-server-list/admin/reports/#{report.id}.json",
        params: { status: "resolved", review_note: "Reviewed manually." }

    expect(response.status).to eq(200)
    report.reload
    expect(report.status).to eq("resolved")
    expect(report.reviewed_by_id).to eq(admin.id)
    expect(report.reviewed_at).to be_present
    expect(report.review_note).to eq("Reviewed manually.")
    server.reload
    expect(server).to be_approved
    expect(server).to be_enabled
  end

  it "rejects invalid or repeated moderation decisions" do
    server = create_server
    report = CrimsonServerList::Report.create!(server: server, reporter: member, reason: "spam")
    sign_in(admin)

    put "/crimson-server-list/admin/reports/#{report.id}.json", params: { status: "delete" }
    expect(response.status).to eq(422)
    expect(report.reload.status).to eq("pending")

    put "/crimson-server-list/admin/reports/#{report.id}.json", params: { status: "dismissed" }
    expect(response.status).to eq(200)

    put "/crimson-server-list/admin/reports/#{report.id}.json", params: { status: "resolved" }
    expect(response.status).to eq(422)
    expect(report.reload.status).to eq("dismissed")
  end

  it "removes report records when the server listing is deleted" do
    server = create_server
    CrimsonServerList::Report.create!(server: server, reporter: member, reason: "spam")

    expect { server.destroy! }.to change { CrimsonServerList::Report.count }.from(1).to(0)
  end
end
