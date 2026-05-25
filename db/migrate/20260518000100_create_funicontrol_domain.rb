class CreateFunicontrolDomain < ActiveRecord::Migration[8.1]
  def change
    create_table :lines do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :status, null: false, default: "normal"
      t.text :description

      t.timestamps
    end
    add_index :lines, :slug, unique: true

    create_table :stations do |t|
      t.references :line, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :position, precision: 6, scale: 4, null: false
      t.string :status, null: false, default: "normal"
      t.integer :passenger_level, null: false, default: 0

      t.timestamps
    end
    add_index :stations, [ :line_id, :position ]

    create_table :cars do |t|
      t.references :line, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code, null: false
      t.decimal :position, precision: 6, scale: 4, null: false
      t.string :direction, null: false, default: "idle"
      t.decimal :speed, precision: 6, scale: 4, null: false, default: 0
      t.string :status, null: false, default: "idle"
      t.datetime :last_seen_at

      t.timestamps
    end
    add_index :cars, [ :line_id, :code ], unique: true

    create_table :incidents do |t|
      t.references :line, null: false, foreign_key: true
      t.references :station, null: true, foreign_key: true
      t.references :car, null: true, foreign_key: true
      t.string :kind, null: false
      t.string :severity, null: false
      t.string :status, null: false, default: "open"
      t.string :title, null: false
      t.text :description
      t.datetime :resolved_at

      t.timestamps
    end
    add_index :incidents, [ :line_id, :status ]
    add_index :incidents, [ :line_id, :severity ]

    create_table :incident_comments do |t|
      t.references :incident, null: false, foreign_key: true
      t.string :author_name, null: false
      t.text :body, null: false

      t.timestamps
    end

    create_table :operation_events do |t|
      t.references :line, null: false, foreign_key: true
      t.references :car, null: true, foreign_key: true
      t.references :station, null: true, foreign_key: true
      t.references :incident, null: true, foreign_key: true
      t.string :event_type, null: false
      t.json :payload, null: false, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end
    add_index :operation_events, [ :line_id, :occurred_at ]
    add_index :operation_events, [ :line_id, :id ]
    add_index :operation_events, :event_type
  end
end
