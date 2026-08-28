# frozen_string_literal: true

class CreateCrimsonServerFollows < ActiveRecord::Migration[7.0]
  def change
    create_table :crimson_server_follows do |t|
      t.bigint :server_id, null: false
      t.integer :user_id, null: false
      t.boolean :notifications_enabled, null: false, default: false
      t.timestamps
    end

    add_index :crimson_server_follows,
              %i[server_id user_id],
              unique: true,
              name: "idx_crimson_server_follow_user"
    add_index :crimson_server_follows, %i[user_id updated_at]
    add_foreign_key :crimson_server_follows,
                    :crimson_game_servers,
                    column: :server_id,
                    on_delete: :cascade
    add_foreign_key :crimson_server_follows, :users, column: :user_id, on_delete: :cascade
  end
end
