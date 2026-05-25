class AddOperationalControlsToFunicontrol < ActiveRecord::Migration[8.1]
  def change
    change_table :lines do |t|
      t.string :weather_condition, null: false, default: "clear"
      t.integer :passenger_satisfaction_score, null: false, default: 100
    end

    change_table :cars do |t|
      t.string :operation_mode, null: false, default: "auto"
      t.datetime :dwell_until
    end

    create_table :track_segments do |t|
      t.references :line, null: false, foreign_key: true
      t.string :name, null: false
      t.string :kind, null: false, default: "speed_limit"
      t.decimal :start_position, precision: 6, scale: 4, null: false
      t.decimal :end_position, precision: 6, scale: 4, null: false
      t.decimal :speed_limit, precision: 6, scale: 4
      t.decimal :gradient, precision: 6, scale: 3

      t.timestamps
    end
    add_index :track_segments, [ :line_id, :start_position, :end_position ]
    add_index :track_segments, [ :line_id, :kind ]

    create_table :daily_reports do |t|
      t.references :line, null: false, foreign_key: true
      t.date :report_date, null: false
      t.json :payload, null: false, default: {}

      t.timestamps
    end
    add_index :daily_reports, [ :line_id, :report_date ], unique: true
  end
end
