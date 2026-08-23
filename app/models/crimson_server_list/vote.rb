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
