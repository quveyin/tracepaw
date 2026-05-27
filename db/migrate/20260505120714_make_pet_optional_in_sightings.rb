class MakePetOptionalInSightings < ActiveRecord::Migration[8.1]
  def change
    change_column_null :sightings, :pet_id, true
  end
end