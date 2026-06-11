class MatchMakerJob < ApplicationJob
  queue_as :default

  def perform(sighting_id)
    sighting = Sighting.find_by(id: sighting_id)
    return unless sighting && sighting.face_embedding.present?

    embedding_string = sighting.face_embedding.is_a?(Array) ? "[#{sighting.face_embedding.join(',')}]" : sighting.face_embedding.to_s
    
    # Mail atma eşiği (Güçlü eşleşme)
    mail_threshold = 0.50

    Rails.logger.info "\n🔍 [MatchMaker] İhbar (ID: #{sighting.id}) için tarama başlatıldı..."

    safe_order_query = ActiveRecord::Base.sanitize_sql_array(["face_embedding <=> ?", embedding_string])
    
    # Tüm hayvanları mesafeye göre sıralayıp getiriyoruz (Limit 50 ile sınırlandırdık ki RAM şişmesin)
    all_sorted_pets = Pet.where("face_embedding IS NOT NULL")
                         .order(Arel.sql(safe_order_query))
                         .limit(50)

    if all_sorted_pets.empty?
      Rails.logger.info "⚠️ [MatchMaker] Sistemde karşılaştırılacak hayvan bulunamadı.\n"
      return
    end

    # Sadece güçlü eşleşenleri (mesafesi 0.50'den küçük olanları) filtreliyoruz
    strong_matches = all_sorted_pets.select do |pet|
      distance_sql = "SELECT (face_embedding <=> '#{embedding_string}'::vector) AS dist FROM pets WHERE id = #{pet.id}"
      distance = ActiveRecord::Base.connection.select_value(distance_sql).to_f
      distance < mail_threshold
    end

    if strong_matches.any?
      Rails.logger.info "🚨 [MatchMaker] #{strong_matches.count} adet GÜÇLÜ eşleşme bulundu! E-postalar gönderiliyor..."
      strong_matches.each do |pet|
        next unless pet.user&.email.present?
        MatchMailer.with(sighting: sighting, pet: pet).match_found.deliver_later
      end
    else
      Rails.logger.info "ℹ️ [MatchMaker] Güçlü eşleşme bulunamadı (E-posta atılmadı). Ancak en yakın #{all_sorted_pets.count} hayvan arayüzde gösterilecek."
    end
    
    Rails.logger.info "✅ [MatchMaker] Süreç tamamlandı.\n"
  rescue => e
    Rails.logger.error "❌ [MatchMaker] Beklenmeyen hata: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if e.backtrace
  end
end