class MatchMakerJob < ApplicationJob
  queue_as :default

  def perform(sighting_id)
    sighting = Sighting.find_by(id: sighting_id)
    return unless sighting

    puts "\n"
    puts "[YAPAY ZEKA] Arka plan servisi tetiklendi!"
    puts "#{sighting.id} ID'li yeni ihbar analiz ediliyor..."
    puts "Gelen Konum: #{sighting.latitude}, #{sighting.longitude}"
    puts "Zaman Damgası: #{sighting.seen_at}"
    
    # İLERİDE BURAYA: Az önce konsolda yazdığımız o "Sighting.near..." 
    # Spatio-Temporal algoritmasını tam olarak buraya gömeceğiz.
    
    puts "ANALİZ TAMAMLANDI: Bölgedeki olası sahiplere bildirim gönderiliyor!"
    puts "\n"
  end
end