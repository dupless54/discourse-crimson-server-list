# frozen_string_literal: true

class CreateCrimsonGameServers < ActiveRecord::Migration[7.0]
  def change
    create_table :crimson_game_servers do |t|
      t.string :game_slug, null: false, limit: 60
      t.integer :owner_id
      t.string :name, null: false, limit: 100
      t.string :slug, null: false, limit: 120
      t.string :short_description, null: false, limit: 180
      t.text :description
      t.string :host, null: false
      t.integer :port, null: false
      t.string :website_url
      t.string :discord_url
      t.string :banner_url
      t.string :country_code, limit: 2
      t.string :language, limit: 60
      t.string :version, limit: 60
      t.string :mode, limit: 60
      t.string :status, null: false, default: "unknown", limit: 20
      t.integer :players_online, null: false, default: 0
      t.integer :players_max, null: false, default: 0
      t.integer :vote_count, null: false, default: 0
      t.boolean :featured, null: false, default: false
      t.boolean :approved, null: false, default: false
      t.boolean :enabled, null: false, default: true
      t.datetime :last_checked_at
      t.timestamps
    end

    add_index :crimson_game_servers, :slug, unique: true
    add_index :crimson_game_servers, :game_slug
    add_index :crimson_game_servers, :owner_id
    add_index :crimson_game_servers, %i[approved enabled]
    add_index :crimson_game_servers, %i[featured vote_count]
  end
end
