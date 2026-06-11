# frozen_string_literal: true

class AddLocationToSightings < ActiveRecord::Migration[8.1]
  def change
    add_column :sightings, :city, :string
    add_column :sightings, :district, :string
    add_column :sightings, :neighborhood, :string
  end
end
