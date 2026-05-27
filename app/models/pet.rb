class Pet < ApplicationRecord
  has_many :sightings
  has_neighbors :face_embedding
end