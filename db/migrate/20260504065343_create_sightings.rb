class CreateSightings < ActiveRecord::Migration[8.1]
  def change
    create_table :sightings do |t|
      t.references :pet, null: false, foreign_key: true
      t.float :latitude
      t.float :longitude
      t.datetime :seen_at
      t.text :description

      t.timestamps
    end
  end
end
