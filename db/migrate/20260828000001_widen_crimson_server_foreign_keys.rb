# frozen_string_literal: true

class WidenCrimsonServerForeignKeys < ActiveRecord::Migration[7.0]
  TABLES = %i[
    crimson_server_votes
    crimson_server_reviews
    crimson_server_claim_requests
  ].freeze
  INTEGER_MAX = 2_147_483_647

  def up
    TABLES.each { |table| change_column table, :server_id, :bigint, null: false }
  end

  def down
    TABLES.each do |table|
      if select_value("SELECT 1 FROM #{quote_table_name(table)} WHERE server_id > #{INTEGER_MAX} LIMIT 1")
        raise ActiveRecord::IrreversibleMigration,
              "#{table}.server_id contains values that cannot fit in a 32-bit integer"
      end

      change_column table, :server_id, :integer, null: false
    end
  end
end
