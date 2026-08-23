# frozen_string_literal: true

class AddServerDetailsViewsAndClaims < ActiveRecord::Migration[7.0]
  def change
    add_column :crimson_game_servers, :game_details, :jsonb, null: false, default: {}
    add_column :crimson_game_servers, :view_count, :bigint, null: false, default: 0

    create_table :crimson_server_claim_requests do |t|
      t.integer :server_id, null: false
      t.integer :requester_id, null: false
      t.string :status, null: false, default: "pending", limit: 20
      t.text :note
      t.integer :reviewed_by_id
      t.datetime :reviewed_at
      t.timestamps
    end

    add_index :crimson_server_claim_requests, :requester_id
    add_index :crimson_server_claim_requests, %i[server_id status]
    add_index :crimson_server_claim_requests,
              %i[server_id requester_id],
              unique: true,
              name: "idx_crimson_server_claim_per_user"
  end
end
