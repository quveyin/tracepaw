import sys
import requests
import cv2
import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image
from ultralytics import YOLO
from datetime import datetime

# Dışarıdan dosya yolu gelmezse uyar
if len(sys.argv) < 2:
    print("Hata: Lütfen analiz edilecek fotoğrafın yolunu belirtin.")
    sys.exit()

fotograf_yolu = sys.argv[1]

print("1. YOLO Modeli yükleniyor (Sadece Kırpma İçin)...")
yolo_model = YOLO("yolov8n.pt") 

print("2. ResNet-50 Biyometrik Model Yükleniyor...")
# Literatürdeki en güçlü omurgalardan biri olan ResNet-50'yi yüklüyoruz
resnet_model = models.resnet50(weights=models.ResNet50_Weights.IMAGENET1K_V2)

# MÜHENDİSLİK HAMLESİ: Sınıflandırma (1000 tür) yerine Biyometrik Vektör istiyoruz.
# ResNet50 normalde 2048 sayı üretir. Rails veritabanımız (pgvector) ise 512 sayı bekliyor.
# Bu yüzden modelin son katmanını 2048'den 512'ye indirecek şekilde güncelliyoruz.
num_ftrs = resnet_model.fc.in_features
resnet_model.fc = nn.Linear(num_ftrs, 512)
resnet_model.eval() # Modeli 'Eğitim' modundan 'Test/Çıkarım' moduna alıyoruz

# Makalelerde geçen standart ResNet ön işleme (Pre-processing) adımları
preprocess = transforms.Compose([
    transforms.Resize(256),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])

orjinal_resim_cv2 = cv2.imread(fotograf_yolu)
if orjinal_resim_cv2 is None:
    print(f"Hata: {fotograf_yolu} bulunamadı!")
    sys.exit()

print(f"\n{fotograf_yolu} analiz ediliyor...")
sonuclar = yolo_model(fotograf_yolu)
sonuc = sonuclar[0]

bulunanlar = []

for kutu in sonuc.boxes:
    sinif_id = int(kutu.cls[0])
    tur_ismi = yolo_model.names[sinif_id]
    guven = float(kutu.conf[0]) * 100
    
    if tur_ismi in ["dog", "cat"] and guven > 60:
        # 1. YOLO ile hayvanı kırp
        x1, y1, x2, y2 = map(int, kutu.xyxy[0])
        kirpilmis_resim = orjinal_resim_cv2[y1:y2, x1:x2]
        
        # 2. Resmi ResNet-50'nin anlayacağı formata (Tensör) çevir
        pil_resim = Image.fromarray(cv2.cvtColor(kirpilmis_resim, cv2.COLOR_BGR2RGB))
        girdi_tensor = preprocess(pil_resim).unsqueeze(0)
        
        # 3. ResNet-50 ile Biyometrik Vektörü (512 boyut) çıkar
        with torch.no_grad():
            vektor_cikti = resnet_model(girdi_tensor)
            biyometrik_yuz_izi = vektor_cikti[0].tolist()
        
        bulunanlar.append({
            "tur": "Köpek" if tur_ismi == "dog" else "Kedi",
            "guven_orani": round(guven, 2),
            "vektor": biyometrik_yuz_izi
        })

print("\n--- ANALİZ SONUCU ---")
if len(bulunanlar) > 0:
    hedef_veri = bulunanlar[0]
    print(f"Tespit: {hedef_veri['tur']} | Güven: %{hedef_veri['guven_orani']}")
    
    # === RAILS BACKEND'E GÖNDERME KISMI ===
    print("Rails API'sine ResNet-50 Biyometrik Vektörü fırlatılıyor...")
    
    rails_paketi = {
        "sighting": {
            "latitude": 41.2867,
            "longitude": 36.3300,
            "description": f"ResNet-50 Biyometrik Analiz: {hedef_veri['tur']}",
            "seen_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "face_embedding": hedef_veri['vektor']
        }
    }
    
    url = "http://localhost:3000/sightings"
    
    try:
        cevap = requests.post(url, json=rails_paketi)
        if cevap.status_code in [200, 201]:
            print("Başarılı! ResNet-50 vektörü Rails (pgvector) kasasına yazıldı. 🚀")
        else:
            print(f"Hata! Rails reddetti. Durum kodu: {cevap.status_code}")
    except Exception as e:
        print(f"Sunucuya ulaşılamadı. Hata: {e}")