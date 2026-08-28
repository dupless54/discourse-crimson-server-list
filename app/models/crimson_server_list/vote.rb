# frozen_string_literal: true

module ::CrimsonServerList
  class Vote < ActiveRecord::Base
    self.table_name = "crimson_server_votes"

    belongs_to :server,
               class_name: "::CrimsonServerList::Server",
               counter_cache: :vote_count,
               inverse_of: :votes
    belongs_to :user, class_name: "::User"

    validates :voted_on, presence: true
    validates :server_id, uniqueness: { scope: %i[user_id voted_on] }
  end
end

# == Schema Information
#
# Table name: crimson_server_votes
#
#  id         :bigint           not null, primary key
#  voted_on   :date             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  server_id  :bigint           not null
#  user_id    :integer          not null
#
# Indexes
#
#  idx_crimson_server_daily_vote            (server_id,user_id,voted_on) UNIQUE
#  index_crimson_server_votes_on_server_id  (server_id)
#  index_crimson_server_votes_on_user_id    (user_id)
#
