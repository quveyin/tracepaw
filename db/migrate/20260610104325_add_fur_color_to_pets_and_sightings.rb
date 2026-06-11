class AddFurColorToPetsAndSightings < ActiveRecord::Migration[8.1]
  def change
    add_column :pets, :fur_color, :string
    add_column :sightings, :fur_color, :string
  end
end
