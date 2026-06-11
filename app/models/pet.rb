class Pet < ApplicationRecord
  belongs_to :user
  has_many :sightings, dependent: :destroy
  has_many_attached :photos
  has_neighbors :face_embedding

  validate :must_have_at_least_one_photo

  def similar_sightings
    return Sighting.none unless face_embedding.present?
    
    # Normalize embedding into a pgvector literal and cast to ::vector for safe comparison
    embedding_contents = if face_embedding.is_a?(Array)
                           face_embedding.join(',')
                         else
                           face_embedding.to_s.gsub(/[\[\]\s]/, '')
                         end
    visual_distance_expr = Pet.sanitize_sql_array(["(sightings.face_embedding <=> (?::vector))", "[#{embedding_contents}]"])

    # Ham görsel benzerlik (CLIP Kalibrasyon Ayarlı)
    raw_visual_score = "(GREATEST(0, ((1 - #{visual_distance_expr}) - 0.70) / (1 - 0.70)) * 100)"

    # Renk Ceza Mekanizması (Color Penalty)
    pet_color_sql = fur_color.nil? ? 'NULL' : ActiveRecord::Base.connection.quote(fur_color.to_s)
    calibrated_visual_score = <<~SQL.squish
      (CASE
         WHEN sightings.fur_color IS NULL OR #{pet_color_sql} IS NULL
           THEN #{raw_visual_score}
         WHEN LOWER(sightings.fur_color) = LOWER(#{pet_color_sql})
           THEN #{raw_visual_score}
         ELSE (#{raw_visual_score} * 0.15)
       END)
    SQL

    pet_lat_sql = latitude.nil? ? 'NULL' : latitude.to_f.to_s
    pet_lng_sql = longitude.nil? ? 'NULL' : longitude.to_f.to_s

    distance_km_expr = <<~SQL.squish
      6371 * acos(
        LEAST(1, GREATEST(-1, (
          cos(radians(#{pet_lat_sql})) * cos(radians(sightings.latitude)) *
          cos(radians(sightings.longitude) - radians(#{pet_lng_sql})) +
          sin(radians(#{pet_lat_sql})) * sin(radians(sightings.latitude))
        )))
      )
    SQL

    spatial_score_calc = "GREATEST(0, 100 - (#{distance_km_expr} * 2))"

    similarity_score_sql = <<~SQL.squish
      (CASE
         WHEN sightings.latitude IS NULL OR sightings.longitude IS NULL OR #{pet_lat_sql}::float IS NULL OR #{pet_lng_sql}::float IS NULL
           THEN ROUND((#{calibrated_visual_score})::numeric, 2)
         ELSE ROUND((0.8 * (#{calibrated_visual_score}) + 0.2 * (#{spatial_score_calc}))::numeric, 2)
       END) AS similarity_score
    SQL

    # TÜRKÇE KARAKTER VE KEDİ/KÖPEK AYRIMI GÜVENLİK DUVARI (İŞTE BURAYI DÜZELTTİK!)
    safe_species = species.to_s.mb_chars.downcase.to_s
    mapped_pet_species = "dog"
    
    # "kedı", "kedi", "ked", "cat" gibi tüm varyasyonları güvenle yakalar
    if safe_species.include?("kedi") || safe_species.include?("ked") || safe_species == "cat"
      mapped_pet_species = "cat"
    end

    Sighting.select("sightings.*, #{similarity_score_sql}")
            .where.not(face_embedding: nil)
            .where("LOWER(species) = ?", mapped_pet_species)
            .order(Arel.sql("similarity_score DESC"))
  end

  private

  def must_have_at_least_one_photo
    return if photos.attached?

    errors.add(:photos, "en az bir fotoğraf yükleyin")
  end
end