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
