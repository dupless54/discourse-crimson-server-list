# frozen_string_literal: true

module ::CrimsonServerList
  class UptimeSample < ActiveRecord::Base
    self.table_name = "crimson_server_uptime_samples"

    belongs_to :server,
               class_name: "::CrimsonServerList::Server",
               inverse_of: :uptime_samples

    validates :sampled_at, presence: true
    validates :status, inclusion: { in: CrimsonServerList::Server::STATUSES }
    validates :players_online,
              :players_max,
              :response_ms,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
              },
              allow_nil: true
    validate :player_counts_match_capability
    validate :players_are_consistent

    private

    def player_counts_match_capability
      return if supports_player_count
      return if players_online.nil? && players_max.nil?

      errors.add(:players_online, :invalid)
    end

    def players_are_consistent
      return if players_online.nil? || players_max.nil? || players_max.zero?
      return if players_online <= players_max

      errors.add(:players_online, :less_than_or_equal_to, count: players_max)
    end
  end
end

# == Schema Information
#
# Table name: crimson_server_uptime_samples
#
#  id                    :bigint           not null, primary key
#  players_max           :integer
#  players_online        :integer
#  response_ms           :integer
#  sampled_at            :datetime         not null
#  status                :string(20)       not null
#  supports_player_count :boolean          default(FALSE), not null
#  server_id             :bigint           not null
#
# Indexes
#
#  idx_crimson_uptime_server_sample                   (server_id,sampled_at) UNIQUE
#  index_crimson_server_uptime_samples_on_sampled_at  (sampled_at)
#
# Foreign Keys
#
#  fk_rails_...  (server_id => crimson_game_servers.id) ON DELETE => cascade
#
