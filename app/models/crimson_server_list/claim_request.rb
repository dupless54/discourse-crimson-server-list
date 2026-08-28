# frozen_string_literal: true

module ::CrimsonServerList
  class ClaimRequest < ActiveRecord::Base
    self.table_name = "crimson_server_claim_requests"

    STATUSES = %w[pending approved rejected].freeze

    belongs_to :server,
               class_name: "::CrimsonServerList::Server",
               inverse_of: :claim_requests
    belongs_to :requester, class_name: "::User"
    belongs_to :reviewed_by, class_name: "::User", optional: true

    validates :status, inclusion: { in: STATUSES }
    validates :requester_id, uniqueness: { scope: :server_id }
    validates :note, length: { maximum: 500 }, allow_blank: true
  end
end

# == Schema Information
#
# Table name: crimson_server_claim_requests
#
#  id             :bigint           not null, primary key
#  note           :text
#  reviewed_at    :datetime
#  status         :string(20)       default("pending"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  requester_id   :integer          not null
#  reviewed_by_id :integer
#  server_id      :bigint           not null
#
# Indexes
#
#  idx_crimson_server_claim_per_user                            (server_id,requester_id) UNIQUE
#  index_crimson_server_claim_requests_on_requester_id          (requester_id)
#  index_crimson_server_claim_requests_on_server_id_and_status  (server_id,status)
#
