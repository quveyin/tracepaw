import sys
import json
import cv2
import torch
import warnings
import os
import contextlib

# Sistem ve PyTorch seviyesindeki gereksiz logları engelle
warnings.filterwarnings("ignore")
os.environ["HF_HUB_DISABLE_SYSLOG_WARNING"] = "1"
os.environ["TOKENIZERS_PARALLELISM"] = "false"

@contextlib.contextmanager
def silence_stdout():
    new_target = open(os.devnull, "w")
    old_stdout = sys.stdout
    sys.stdout = new_target
    try:
        yield
    finally:
        sys.stdout = old_stdout
        new_target.close()

from PIL import Image

with silence_stdout():
    from ultralytics import YOLO
    from transformers import CLIPProcessor, CLIPModel, logging as hf_logging
    hf_logging.set_verbosity_error()

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"status": "error", "message": "Image path not provided"}))
        sys.exit(1)

    image_path = sys.argv[1]

    yolo_model = YOLO("yolov8n.pt")
    model_id = "openai/clip-vit-base-patch32"
    processor = CLIPProcessor.from_pretrained(model_id)
    model = CLIPModel.from_pretrained(model_id)
    model.eval()

    original_image = cv2.imread(image_path)
    if original_image is None:
        print(json.dumps({"status": "error", "message": f"Image not found at {image_path}"}))
        sys.exit(1)

    results = yolo_model(image_path, verbose=False)
    result = results[0]

    detections = []
 
    color_labels = [
        "orange or ginger fur",          # Turuncu / Sarman
        "grey or silver fur",            # Gri / Duman rengi
        "solid black fur",               # Tamamen siyah
        "solid white fur",               # Tamamen beyaz
        "brown or chocolate fur",        # Kahverengi
        "golden or yellow fur",          # Golden / Sarı (Köpekler için)
        "black and tan bicolor fur",     # Siyah-Taba (Alman Kurdu, Rottweiler)
        "tabby pattern with stripes",    # Tekir desenli (Çizgili) - İŞTE O GRİ KEDİNİN KURTULACAĞI YER!
        "bicolor or tuxedo pattern",     # İki renkli / Smokin (Göğsü beyaz, üstü başka renk)
        "calico or tortoiseshell fur"    # Üç renkli (Calico / Tortie)
    ]
    color_mapping = [
        "orange", "grey", "black", "white", "brown", "golden", 
        "black_and_tan", "tabby", "bicolor", "calico"
    ]

    for box in result.boxes:
        class_id = int(box.cls[0])
        class_name = yolo_model.names[class_id]
        confidence = float(box.conf[0]) * 100
        
        # CASUS LOG: YOLO'nun gördüğü her şeyi Rails terminalinde görebilmek için stderr'e yazıyoruz
        print(f"[YOLO CASUS LOG] Sınıf: {class_name} | Güven Skoru: %{confidence:.2f}", file=sys.stderr)
        
        # BILIMSEL DÜZELTME: Güven barajını %60'tan %40'a düşürerek zorlu pozları yakalıyoruz
        if class_name in ["dog", "cat"] and confidence > 40:
            x1, y1, x2, y2 = map(int, box.xyxy[0])
            cropped_image = original_image[y1:y2, x1:x2]
            
            if cropped_image.size == 0:
                continue

            pil_image = Image.fromarray(cv2.cvtColor(cropped_image, cv2.COLOR_BGR2RGB))
            inputs = processor(text=color_labels, images=pil_image, return_tensors="pt", padding=True)
            
            with silence_stdout():
                with torch.no_grad():
                    outputs = model(**inputs)
                    
                    image_features = outputs.image_embeds
                    image_features = image_features / image_features.norm(p=2, dim=-1, keepdim=True)
                    face_embedding = image_features[0].tolist()
                    
                    logits_per_image = outputs.logits_per_image
                    probs = logits_per_image.softmax(dim=-1)
                    scores = probs[0].tolist()
                    detected_color = color_mapping[probs.argmax().item()]
            
            detections.append({
                "type": "Dog" if class_name == "dog" else "Cat",
                "confidence": round(confidence, 2),
                "embedding": face_embedding,
                "color": detected_color,
                "color_scores": {k: v for k, v in zip(color_mapping, scores)}
            })

    if not detections:
        print(json.dumps({"status": "error", "message": "No dogs or cats detected"}))
        sys.exit(1)

    top = detections[0]
    out = {
        "status": "success",
        "type": top["type"],
        "tur": top["type"],
        "confidence": top["confidence"],
        "guven": top["confidence"],
        "face_embedding": top["embedding"],
        "renk": top["color"],
        "fur_color": top["color"],
        "fur_color_scores": top["color_scores"]
    }
    print(json.dumps(out))

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(json.dumps({"status": "error", "message": f"Unhandled error: {str(e)}"}))
        sys.exit(1)