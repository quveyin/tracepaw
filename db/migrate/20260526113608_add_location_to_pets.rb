class AddLocationToPets < ActiveRecord::Migration[8.1]
  def change
    add_column :pets, :latitude, :float
    add_column :pets, :longitude, :float
  end
end
