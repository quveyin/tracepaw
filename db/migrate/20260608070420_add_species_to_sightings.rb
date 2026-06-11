class AddSpeciesToSightings < ActiveRecord::Migration[8.1]
  def change
    add_column :sightings, :species, :string
  end
end
