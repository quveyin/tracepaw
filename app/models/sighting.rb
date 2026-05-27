class Sighting < ApplicationRecord
  belongs_to :pet, optional: true
  reverse_geocoded_by :latitude, :longitude
  has_one_attached :photo
  has_neighbors :face_embedding
end
