# frozen_string_literal: true

class CreateCrimsonServerUptimeSamples < ActiveRecord::Migration[7.0]
  def change
    create_table :crimson_server_uptime_samples do |t|
      t.bigint :server_id, null: false
      t.datetime :sampled_at, null: false
      t.string :status, null: false, limit: 20
      t.integer :players_online
      t.integer :players_max
      t.integer :response_ms
      t.boolean :supports_player_count, null: false, default: false
    end

    add_index :crimson_server_uptime_samples,
              %i[server_id sampled_at],
              unique: true,
              name: "idx_crimson_uptime_server_sample"
    add_index :crimson_server_uptime_samples, :sampled_at
    add_foreign_key :crimson_server_uptime_samples,
                    :crimson_game_servers,
                    column: :server_id,
                    on_delete: :cascade
  end
end
