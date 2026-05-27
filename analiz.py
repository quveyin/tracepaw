import requests

tespit_edilen_nesneler = [
    {"tur": "Araba", "enlem": 41.2867, "boylam": 36.3300, "guven_orani": 95},
    {"tur": "Köpek", "enlem": 41.2870, "boylam": 36.3315, "guven_orani": 89},
    {"tur": "İnsan", "enlem": 41.2865, "boylam": 36.3290, "guven_orani": 99},
    {"tur": "Kedi", "enlem": 41.2875, "boylam": 36.3320, "guven_orani": 65}  
]

aranan_turler = ["Köpek", "Kedi"]

gonderilecek_veriler = []

print("Görüntü analizi başlatılıyor...\n")

for nesne in tespit_edilen_nesneler:
    if nesne["tur"] in aranan_turler:
        
        if nesne["guven_orani"] > 80:
            print("Eşleşme Bulundu! Tür:", nesne["tur"], "- Güven Oranı: %", nesne["guven_orani"])
            gonderilecek_veriler.append(nesne)
        else:
            print("Göz ardı edildi: Bir", nesne["tur"], "görüldü ama sistem yeterince emin değil. (Güven: %", nesne["guven_orani"], ")")
            
print("\nAnaliz tamamlandı.")
print("Rails veritabanına aktarılacak son liste:")
print(gonderilecek_veriler)

if len(gonderilecek_veriler) > 0:
    hedef_veri = gonderilecek_veriler[0]
    
    rails_paketi = {
        "sighting": {
            "pet_id": 1,
            "latitude": hedef_veri["enlem"],
            "longitude": hedef_veri["boylam"],
            "description": f"Python algoritması %{hedef_veri['guven_orani']} güvenle tespit etti!",
            "seen_at": "2026-05-04 10:04:50" 
        }
    }
    
    url = "http://localhost:3000/sightings"
    
    print(f"\n{url} adresine paket fırlatılıyor...")

    cevap = requests.post(url, json=rails_paketi)
    
    if cevap.status_code == 200 or cevap.status_code == 201:
        print("İşte bu! Veri başarıyla Rails'e ulaştı ve veritabanına yazıldı.")
    else:
        print("Hata! Rails kapı duvar. Dönen durum kodu:", cevap.status_code)