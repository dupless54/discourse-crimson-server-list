# frozen_string_literal: true

class AddTagsToCrimsonGameServers < ActiveRecord::Migration[7.0]
  def change
    add_column :crimson_game_servers, :tags, :jsonb, null: false, default: []
    add_index :crimson_game_servers, :tags, using: :gin
  end
end
