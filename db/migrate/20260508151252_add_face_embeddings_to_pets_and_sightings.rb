class AddFaceEmbeddingsToPetsAndSightings < ActiveRecord::Migration[8.1]
  def up
    enable_extension 'vector'

    add_column :pets, :face_embedding, :vector, limit: 512
    add_column :sightings, :face_embedding, :vector, limit: 512
  end

  def down
    remove_column :sightings, :face_embedding
    remove_column :pets, :face_embedding
    disable_extension 'vector'
  end
end