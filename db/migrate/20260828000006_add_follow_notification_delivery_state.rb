# frozen_string_literal: true

class AddFollowNotificationDeliveryState < ActiveRecord::Migration[7.0]
  def change
    add_column :crimson_server_follows, :last_online_notification_at, :datetime
  end
end
