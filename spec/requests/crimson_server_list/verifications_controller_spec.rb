# frozen_string_literal: true

RSpec.describe CrimsonServerList::VerificationsController do
  let!(:owner) { Fabricate(:user) }
  let!(:member) { Fabricate(:user) }

  before do
    SiteSetting.crimson_server_list_enabled = true
    SiteSetting.crimson_server_list_verification_enabled = true
    SiteSetting.crimson_server_list_verification_challenge_hours = 24
  end

  def create_server(owner: self.owner, approved: true, host: "play.example.net", name: "Verification API Server")
    CrimsonServerList::Server.create!(
      owner: owner,
      game_slug: "minecraft",
      name: name,
      short_description: "Verification request-spec fixture.",
      host: host,
      port: 25_565,
      approved: approved,
      enabled: true,
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

  it "requires login and listing ownership to create a challenge" do
    server = create_server
    path = "/crimson-server-list/servers/#{server.id}/verification.json"

    post path
    expect(response.status).to eq(403)

    sign_in(member)
    post path
    expect(response.status).to eq(403)
    expect(server.reload.verification_token_digest).to be_nil
  end

  it "returns the plaintext challenge only in the owner start response" do
    server = create_server
    sign_in(owner)

    post "/crimson-server-list/servers/#{server.id}/verification.json"

    expect(response.status).to eq(200)
    challenge = json_body.dig(:verification, :challenge)
    expect(challenge[:record_name]).to eq("_crimson-server-list.play.example.net")
    expect(challenge[:record_value]).to start_with("crimson-server-list=")
    expect(server.reload.verification_token_digest).to eq(
      Digest::SHA256.hexdigest(challenge[:record_value]),
    )
    expect(response.body).not_to include(server.verification_token_digest)
  end

  it "lets the owner check DNS and marks the listing verified" do
    server = create_server
    sign_in(owner)

    post "/crimson-server-list/servers/#{server.id}/verification.json"
    challenge = json_body.dig(:verification, :challenge)
    allow(CrimsonServerList::VerificationService).to receive(:lookup_txt_values).and_return(
      [challenge[:record_value]],
    )

    post "/crimson-server-list/servers/#{server.id}/verification/check.json"

    expect(response.status).to eq(200)
    expect(json_body.dig(:verification, :verified)).to eq(true)
    expect(server.reload).to be_verified
  end

  it "does not expose challenge secrets through the verification status endpoint" do
    server = create_server
    sign_in(owner)
    post "/crimson-server-list/servers/#{server.id}/verification.json"
    digest = server.reload.verification_token_digest

    get "/crimson-server-list/servers/#{server.id}/verification.json"

    expect(response.status).to eq(200)
    expect(json_body.dig(:verification, :pending)).to eq(true)
    expect(json_body.dig(:verification, :record_name)).to eq(
      "_crimson-server-list.play.example.net",
    )
    expect(response.body).not_to include(digest)
    expect(json_body.dig(:verification, :challenge)).to be_nil
  end

  it "keeps unpublished verification state private from other members" do
    server = create_server(approved: false)
    sign_in(member)

    get "/crimson-server-list/servers/#{server.id}/verification.json"

    expect(response.status).to eq(404)
  end

  it "returns only public server verification state from the batch endpoint" do
    public_server = create_server(name: "Public Verified Server")
    hidden_server = create_server(approved: false, name: "Hidden Verified Server", host: "hidden.example.net")
    now = Time.zone.now
    public_server.update_columns(verified_at: now, verification_method: "dns_txt")
    hidden_server.update_columns(verified_at: now, verification_method: "dns_txt")

    get "/crimson-server-list/verifications.json",
        params: { ids: "#{public_server.id},#{hidden_server.id}" }

    expect(response.status).to eq(200)
    verifications = json_body[:verifications]
    expect(verifications.length).to eq(1)
    expect(verifications.first[:server_id]).to eq(public_server.id)
    expect(verifications.first[:verified]).to eq(true)
    expect(verifications.first.keys).to contain_exactly(
      "server_id",
      "verified",
      "verified_at",
      "verification_method",
    )
  end

  it "does not start new verification challenges when the feature is disabled" do
    server = create_server
    SiteSetting.crimson_server_list_verification_enabled = false
    sign_in(owner)

    post "/crimson-server-list/servers/#{server.id}/verification.json"

    expect(response.status).to eq(403)
    expect(server.reload.verification_token_digest).to be_nil
  end
end
