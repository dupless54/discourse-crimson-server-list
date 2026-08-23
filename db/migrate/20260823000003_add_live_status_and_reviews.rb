# frozen_string_literal: true

class AddLiveStatusAndReviews < ActiveRecord::Migration[7.0]
  def change
    add_column :crimson_game_servers, :query_port, :integer
    add_column :crimson_game_servers, :monitoring_enabled, :boolean, null: false, default: true
    add_column :crimson_game_servers, :last_query_error, :string, limit: 500
    add_column :crimson_game_servers, :last_response_ms, :integer
    add_column :crimson_game_servers, :review_count, :integer, null: false, default: 0
    add_column :crimson_game_servers, :rating_sum, :integer, null: false, default: 0

    add_index :crimson_game_servers, %i[approved enabled monitoring_enabled],
              name: "idx_crimson_servers_live_monitoring"

    create_table :crimson_server_reviews do |t|
      t.integer :server_id, null: false
      t.integer :user_id, null: false
      t.integer :rating, null: false
      t.text :body, null: false
      t.timestamps
    end

    add_index :crimson_server_reviews, :server_id
    add_index :crimson_server_reviews, :user_id
    add_index :crimson_server_reviews,
              %i[server_id user_id],
              unique: true,
              name: "idx_crimson_server_review_per_user"
  end
end
