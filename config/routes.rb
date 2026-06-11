Rails.application.routes.draw do
  # 1. Kullanıcı Giriş/Çıkış Sistemi (Devise)
  devise_for :users

  # 2. Ana Sayfa (Landing Page)
  # Kullanıcı siteye girdiğinde pages_controller'ın içindeki index metoduna gitsin
  root "pages#index"

  # 3. Kayıp İlanları ve Yüz Taramaları (Resources)
  resources :pets
  resources :sightings
  
  # Uygulama sağlığı için otomatik eklenen rota (Dokunma)
  get "up" => "rails/health#show", as: :rails_health_check
end