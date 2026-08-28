# frozen_string_literal: true

class CreateCrimsonServerReports < ActiveRecord::Migration[7.0]
  def change
    create_table :crimson_server_reports do |t|
      t.bigint :server_id, null: false
      t.integer :reporter_id, null: false
      t.string :reason, null: false, limit: 30
      t.text :details
      t.string :status, null: false, default: "pending", limit: 20
      t.integer :reviewed_by_id
      t.datetime :reviewed_at
      t.text :review_note
      t.timestamps
    end

    add_index :crimson_server_reports, :reporter_id
    add_index :crimson_server_reports, %i[server_id status]
    add_index :crimson_server_reports, %i[status created_at]
    add_index :crimson_server_reports,
              %i[server_id reporter_id],
              unique: true,
              where: "status = 'pending'",
              name: "idx_crimson_report_pending_per_user"
  end
end
