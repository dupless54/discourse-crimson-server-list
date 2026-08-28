# frozen_string_literal: true

module ::CrimsonServerList
  class Review < ActiveRecord::Base
    self.table_name = "crimson_server_reviews"

    belongs_to :server,
               class_name: "::CrimsonServerList::Server",
               inverse_of: :reviews
    belongs_to :user, class_name: "::User"

    validates :rating,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 1,
                less_than_or_equal_to: 5,
              }
    validates :body, presence: true, length: { maximum: 2_000 }
    validates :server_id, uniqueness: { scope: :user_id }

    before_validation :normalize_body

    private

    def normalize_body
      self.body = body.to_s.strip
    end
  end
end

# == Schema Information
#
# Table name: crimson_server_reviews
#
#  id         :bigint           not null, primary key
#  body       :text             not null
#  rating     :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  server_id  :integer          not null
#  user_id    :integer          not null
#
# Indexes
#
#  idx_crimson_server_review_per_user         (server_id,user_id) UNIQUE
#  index_crimson_server_reviews_on_server_id  (server_id)
#  index_crimson_server_reviews_on_user_id    (user_id)
#
