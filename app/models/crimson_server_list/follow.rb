# frozen_string_literal: true

module ::CrimsonServerList
  class Follow < ActiveRecord::Base
    self.table_name = "crimson_server_follows"

    belongs_to :server, class_name: "::CrimsonServerList::Server"
    belongs_to :user, class_name: "::User"

    validates :user_id, uniqueness: { scope: :server_id }
  end
end

# == Schema Information
#
# Table name: crimson_server_follows
#
#  id                    :bigint           not null, primary key
#  notifications_enabled :boolean          default(FALSE), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  server_id             :bigint           not null
#  user_id               :integer          not null
#
# Indexes
#
#  idx_crimson_server_follow_user                         (server_id,user_id) UNIQUE
#  index_crimson_server_follows_on_user_id_and_updated_at  (user_id,updated_at)
#
# Foreign Keys
#
#  fk_rails_...  (server_id => crimson_game_servers.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
