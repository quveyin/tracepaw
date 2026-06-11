# frozen_string_literal: true

class AddDetailsToPets < ActiveRecord::Migration[8.1]
  def change
    add_column :pets, :age, :integer
    add_column :pets, :city, :string
    add_column :pets, :district, :string
    add_column :pets, :neighborhood, :string
    # Make this reference nullable initially to avoid migration failures
    # for existing records. Backfill and enforce NOT NULL in a later migration.
    add_reference :pets, :user, null: true, foreign_key: true
  end
end
