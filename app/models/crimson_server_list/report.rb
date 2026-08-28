# frozen_string_literal: true

module ::CrimsonServerList
  class Report < ActiveRecord::Base
    self.table_name = "crimson_server_reports"

    REASONS = %w[spam misleading impersonation unsafe unreachable other].freeze
    STATUSES = %w[pending resolved dismissed].freeze

    belongs_to :server,
               class_name: "::CrimsonServerList::Server",
               inverse_of: :reports
    belongs_to :reporter, class_name: "::User"
    belongs_to :reviewed_by, class_name: "::User", optional: true

    validates :reason, inclusion: { in: REASONS }
    validates :status, inclusion: { in: STATUSES }
    validates :details, length: { maximum: 1000 }, allow_blank: true
    validates :review_note, length: { maximum: 1000 }, allow_blank: true
    validates :reporter_id,
              uniqueness: {
                scope: :server_id,
                conditions: -> { where(status: "pending") },
              },
              if: :pending?
    validate :reporter_is_not_server_owner, on: :create
    validate :details_present_for_other_reason

    def pending?
      status == "pending"
    end

    private

    def reporter_is_not_server_owner
      return if reporter_id.blank? || server.blank? || reporter_id != server.owner_id

      errors.add(:reporter, :invalid)
    end

    def details_present_for_other_reason
      return unless reason == "other" && details.blank?

      errors.add(:details, :blank)
    end
  end
end

# == Schema Information
#
# Table name: crimson_server_reports
#
#  id             :bigint           not null, primary key
#  details        :text
#  reason         :string(30)       not null
#  review_note    :text
#  reviewed_at    :datetime
#  status         :string(20)       default("pending"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  reporter_id    :integer          not null
#  reviewed_by_id :integer
#  server_id      :bigint           not null
#
# Indexes
#
#  idx_crimson_report_pending_per_user                    (server_id,reporter_id) UNIQUE WHERE ((status)::text = 'pending'::text)
#  index_crimson_server_reports_on_reporter_id            (reporter_id)
#  index_crimson_server_reports_on_server_id_and_status   (server_id,status)
#  index_crimson_server_reports_on_status_and_created_at  (status,created_at)
#
