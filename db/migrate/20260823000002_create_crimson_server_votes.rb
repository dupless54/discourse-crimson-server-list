# frozen_string_literal: true

class CreateCrimsonServerVotes < ActiveRecord::Migration[7.0]
  def change
    create_table :crimson_server_votes do |t|
      t.integer :server_id, null: false
      t.integer :user_id, null: false
      t.date :voted_on, null: false
      t.timestamps
    end

    add_index :crimson_server_votes, :server_id
    add_index :crimson_server_votes, :user_id
    add_index :crimson_server_votes,
              %i[server_id user_id voted_on],
              unique: true,
              name: "idx_crimson_server_daily_vote"
  end
end
