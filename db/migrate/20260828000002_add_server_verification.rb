# frozen_string_literal: true

class AddServerVerification < ActiveRecord::Migration[7.0]
  def change
    add_column :crimson_game_servers, :verified_at, :datetime
    add_column :crimson_game_servers, :verification_method, :string, limit: 20
    add_column :crimson_game_servers, :verification_token_digest, :string, limit: 64
    add_column :crimson_game_servers, :verification_requested_at, :datetime
    add_column :crimson_game_servers, :verification_expires_at, :datetime

    add_index :crimson_game_servers, :verified_at
  end
end
