# frozen_string_literal: true

RSpec.describe CrimsonServerList::VerificationService do
  let!(:owner) { Fabricate(:user) }
  let!(:new_owner) { Fabricate(:user) }

  before do
    SiteSetting.crimson_server_list_verification_enabled = true
    SiteSetting.crimson_server_list_verification_challenge_hours = 24
  end

  def create_server(host: "play.example.net")
    CrimsonServerList::Server.create!(
      owner: owner,
      game_slug: "minecraft",
      name: "Verified Test Server",
      short_description: "Verification service test fixture.",
      host: host,
      port: 25_565,
      approved: true,
      enabled: true,
      status: "online",
      players_online: 1,
      players_max: 20,
      tags: [],
      game_details: {},
    )
  end

  it "creates a DNS TXT challenge without storing its plaintext value" do
    server = create_server

    challenge = described_class.start!(server)
    server.reload

    expect(challenge[:record_type]).to eq("TXT")
    expect(challenge[:record_name]).to eq("_crimson-server-list.play.example.net")
    expect(challenge[:record_value]).to start_with("crimson-server-list=")
    expect(server.verification_token_digest).to eq(Digest::SHA256.hexdigest(challenge[:record_value]))
    expect(server.attributes.values).not_to include(challenge[:record_value])
    expect(server.verification_expires_at).to be > Time.zone.now
    expect(server).not_to be_verified
  end

  it "marks the server verified only when the expected TXT value is present" do
    server = create_server
    challenge = described_class.start!(server)

    allow(described_class).to receive(:lookup_txt_values).and_return(
      ["unrelated=value", challenge[:record_value]],
    )

    described_class.verify!(server.reload)
    server.reload

    expect(server).to be_verified
    expect(server.verification_method).to eq("dns_txt")
    expect(server.verification_token_digest).to be_nil
    expect(server.verification_requested_at).to be_nil
    expect(server.verification_expires_at).to be_nil
  end

  it "does not verify when the TXT value does not match" do
    server = create_server
    described_class.start!(server)
    allow(described_class).to receive(:lookup_txt_values).and_return(["crimson-server-list=wrong"])

    expect { described_class.verify!(server.reload) }.to raise_error(
      CrimsonServerList::VerificationService::VerificationFailed,
    )
    expect(server.reload).not_to be_verified
  end

  it "does not perform a DNS lookup for an expired challenge" do
    server = create_server
    described_class.start!(server)
    server.update_columns(verification_expires_at: 1.minute.ago)

    expect(described_class).not_to receive(:lookup_txt_values)
    expect { described_class.verify!(server.reload) }.to raise_error(
      CrimsonServerList::VerificationService::ChallengeExpired,
    )
  end

  it "rejects IP literals for automatic verification" do
    server = create_server(host: "1.1.1.1")

    expect(described_class.eligible?(server)).to eq(false)
    expect { described_class.start!(server) }.to raise_error(
      CrimsonServerList::VerificationService::NotEligible,
    )
  end

  it "revokes verification when the host changes" do
    server = create_server
    challenge = described_class.start!(server)
    allow(described_class).to receive(:lookup_txt_values).and_return([challenge[:record_value]])
    described_class.verify!(server.reload)

    server.update!(host: "new.example.net")

    expect(server).not_to be_verified
    expect(server.verification_method).to be_nil
    expect(server.verification_token_digest).to be_nil
  end

  it "revokes verification when the listing owner changes" do
    server = create_server
    challenge = described_class.start!(server)
    allow(described_class).to receive(:lookup_txt_values).and_return([challenge[:record_value]])
    described_class.verify!(server.reload)

    server.update!(owner: new_owner)

    expect(server).not_to be_verified
    expect(server.verification_method).to be_nil
    expect(server.verification_token_digest).to be_nil
  end
end
