# frozen_string_literal: true

class WidenCrimsonServerForeignKeys < ActiveRecord::Migration[7.0]
  TABLES = %i[
    crimson_server_votes
    crimson_server_reviews
    crimson_server_claim_requests
  ].freeze

  def up
    TABLES.each { |table| change_column table, :server_id, :bigint, null: false }
  end

  def down
    TABLES.each { |table| change_column table, :server_id, :integer, null: false }
  end
end
