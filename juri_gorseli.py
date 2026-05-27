import cv2
import sys

# Test edilecek fotoğraf (İstersen test_kedi2.jpg yapabilirsin)
fotograf_yolu = "test_kedi.jpg"
resim = cv2.imread(fotograf_yolu)

if resim is None:
    print("Fotoğraf bulunamadı!")
    sys.exit()

gri_format = cv2.cvtColor(resim, cv2.COLOR_BGR2GRAY)

# BİLGİSAYARLI GÖRÜ ODAK NOKTALARI (Shi-Tomasi Corner Detection)
# CNN modelinin (ResNet-50) özellik çıkarırken baktığı o keskin kenarları, 
# gözleri ve burun hatlarını tespit ediyoruz.
odak_noktalari = cv2.goodFeaturesToTrack(gri_format, maxCorners=60, qualityLevel=0.01, minDistance=15)

# Bulunan her bir kritik biyometrik noktanın üzerine yeşil bir daire çiz
if odak_noktalari is not None:
    for nokta in odak_noktalari:
        x, y = nokta.ravel()
        # (0, 255, 0) -> Yeşil renk, -1 -> İçi dolu daire
        cv2.circle(resim, (int(x), int(y)), 4, (0, 255, 0), -1) 

kayit_adi = "juri_icin_isaretli_" + fotograf_yolu
cv2.imwrite(kayit_adi, resim)
print(f"Başarılı! Biyometrik noktaları işaretlenmiş görsel kaydedildi: {kayit_adi}")