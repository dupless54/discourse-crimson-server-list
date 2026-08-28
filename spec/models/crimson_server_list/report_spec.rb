# frozen_string_literal: true

RSpec.describe CrimsonServerList::Report do
  let!(:owner) { Fabricate(:user) }
  let!(:reporter) { Fabricate(:user) }

  def create_server
    CrimsonServerList::Server.create!(
      owner: owner,
      game_slug: "minecraft",
      name: "Report Model Server",
      short_description: "Reporting model-spec fixture.",
      host: "report-model.example.net",
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

  it "enforces one pending report per reporter and server at the database layer" do
    server = create_server
    described_class.create!(server: server, reporter: reporter, reason: "spam")
    now = Time.zone.now

    expect do
      described_class.insert_all!(
        [
          {
            server_id: server.id,
            reporter_id: reporter.id,
            reason: "unsafe",
            status: "pending",
            created_at: now,
            updated_at: now,
          },
        ],
      )
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "allows another pending report after an earlier report is resolved" do
    server = create_server
    described_class.create!(
      server: server,
      reporter: reporter,
      reason: "spam",
      status: "resolved",
    )

    next_report = described_class.create!(server: server, reporter: reporter, reason: "unsafe")

    expect(next_report).to be_pending
    expect(described_class.where(server: server, reporter: reporter).count).to eq(2)
  end
end
