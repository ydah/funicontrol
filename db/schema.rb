# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_25_000100) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "cars", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "direction", default: "idle", null: false
    t.datetime "dwell_until"
    t.datetime "last_seen_at"
    t.integer "line_id", null: false
    t.string "name", null: false
    t.string "operation_mode", default: "auto", null: false
    t.decimal "position", precision: 6, scale: 4, null: false
    t.decimal "speed", precision: 6, scale: 4, default: "0.0", null: false
    t.string "status", default: "idle", null: false
    t.datetime "updated_at", null: false
    t.index ["line_id", "code"], name: "index_cars_on_line_id_and_code", unique: true
    t.index ["line_id"], name: "index_cars_on_line_id"
  end

  create_table "daily_reports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "line_id", null: false
    t.json "payload", default: {}, null: false
    t.date "report_date", null: false
    t.datetime "updated_at", null: false
    t.index ["line_id", "report_date"], name: "index_daily_reports_on_line_id_and_report_date", unique: true
    t.index ["line_id"], name: "index_daily_reports_on_line_id"
  end

  create_table "incident_comments", force: :cascade do |t|
    t.string "author_name", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.integer "incident_id", null: false
    t.datetime "updated_at", null: false
    t.index ["incident_id"], name: "index_incident_comments_on_incident_id"
  end

  create_table "incidents", force: :cascade do |t|
    t.integer "car_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "kind", null: false
    t.integer "line_id", null: false
    t.datetime "resolved_at"
    t.string "severity", null: false
    t.integer "station_id"
    t.string "status", default: "open", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["car_id"], name: "index_incidents_on_car_id"
    t.index ["line_id", "severity"], name: "index_incidents_on_line_id_and_severity"
    t.index ["line_id", "status"], name: "index_incidents_on_line_id_and_status"
    t.index ["line_id"], name: "index_incidents_on_line_id"
    t.index ["station_id"], name: "index_incidents_on_station_id"
  end

  create_table "lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "passenger_satisfaction_score", default: 100, null: false
    t.string "slug", null: false
    t.string "status", default: "normal", null: false
    t.datetime "updated_at", null: false
    t.string "weather_condition", default: "clear", null: false
    t.index ["slug"], name: "index_lines_on_slug", unique: true
  end

  create_table "operation_events", force: :cascade do |t|
    t.integer "car_id"
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.integer "incident_id"
    t.integer "line_id", null: false
    t.datetime "occurred_at", null: false
    t.json "payload", default: {}, null: false
    t.integer "station_id"
    t.datetime "updated_at", null: false
    t.index ["car_id"], name: "index_operation_events_on_car_id"
    t.index ["event_type"], name: "index_operation_events_on_event_type"
    t.index ["incident_id"], name: "index_operation_events_on_incident_id"
    t.index ["line_id", "id"], name: "index_operation_events_on_line_id_and_id"
    t.index ["line_id", "occurred_at"], name: "index_operation_events_on_line_id_and_occurred_at"
    t.index ["line_id"], name: "index_operation_events_on_line_id"
    t.index ["station_id"], name: "index_operation_events_on_station_id"
  end

  create_table "stations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "line_id", null: false
    t.string "name", null: false
    t.integer "passenger_level", default: 0, null: false
    t.decimal "position", precision: 6, scale: 4, null: false
    t.string "status", default: "normal", null: false
    t.datetime "updated_at", null: false
    t.index ["line_id", "position"], name: "index_stations_on_line_id_and_position"
    t.index ["line_id"], name: "index_stations_on_line_id"
  end

  create_table "track_segments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "end_position", precision: 6, scale: 4, null: false
    t.decimal "gradient", precision: 6, scale: 3
    t.string "kind", default: "speed_limit", null: false
    t.integer "line_id", null: false
    t.string "name", null: false
    t.decimal "speed_limit", precision: 6, scale: 4
    t.decimal "start_position", precision: 6, scale: 4, null: false
    t.datetime "updated_at", null: false
    t.index ["line_id", "kind"], name: "index_track_segments_on_line_id_and_kind"
    t.index ["line_id", "start_position", "end_position"], name: "idx_on_line_id_start_position_end_position_412f46e335"
    t.index ["line_id"], name: "index_track_segments_on_line_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cars", "lines"
  add_foreign_key "daily_reports", "lines"
  add_foreign_key "incident_comments", "incidents"
  add_foreign_key "incidents", "cars"
  add_foreign_key "incidents", "lines"
  add_foreign_key "incidents", "stations"
  add_foreign_key "operation_events", "cars"
  add_foreign_key "operation_events", "incidents"
  add_foreign_key "operation_events", "lines"
  add_foreign_key "operation_events", "stations"
  add_foreign_key "stations", "lines"
  add_foreign_key "track_segments", "lines"
end
