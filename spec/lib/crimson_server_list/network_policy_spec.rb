# frozen_string_literal: true

RSpec.describe CrimsonServerList::NetworkPolicy do
  describe ".hostname_allowed?" do
    it "rejects local and reserved development suffixes" do
      expect(described_class.hostname_allowed?("localhost")).to eq(false)
      expect(described_class.hostname_allowed?("node.internal")).to eq(false)
      expect(described_class.hostname_allowed?("service.example")).to eq(false)
    end

    it "allows an ordinary public hostname when no suffix allowlist is configured" do
      SiteSetting.crimson_server_list_allowed_host_suffixes = ""

      expect(described_class.hostname_allowed?("play.example.net")).to eq(true)
    end
  end

  describe ".public_ip?" do
    it "rejects private, loopback, link-local, documentation, and unique-local addresses" do
      %w[
        127.0.0.1
        10.0.0.1
        169.254.1.1
        192.0.2.10
        203.0.113.10
        ::1
        fc00::1
        fe80::1
      ].each { |address| expect(described_class.public_ip?(address)).to eq(false) }
    end

    it "accepts routable public addresses" do
      expect(described_class.public_ip?("1.1.1.1")).to eq(true)
      expect(described_class.public_ip?("2606:4700:4700::1111")).to eq(true)
    end
  end

  describe ".port_allowed?" do
    it "uses the game-specific allowlist" do
      expect(described_class.port_allowed?("minecraft", 25_565)).to eq(true)
      expect(described_class.port_allowed?("minecraft", 22)).to eq(false)
      expect(described_class.port_allowed?("fivem", 30_120)).to eq(true)
    end
  end

  describe ".resolve!" do
    it "rejects a private IP literal before opening a connection" do
      expect do
        described_class.resolve!("127.0.0.1", port: 25_565, game_slug: "minecraft")
      end.to raise_error(CrimsonServerList::NetworkPolicy::BlockedTarget)
    end
  end
end
