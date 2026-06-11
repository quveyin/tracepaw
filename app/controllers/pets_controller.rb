class PetsController < ApplicationController
  before_action :authenticate_user!, only: %i[new create]
  before_action :set_pet, only: %i[show]

  def index
    pets = Pet.all
    respond_to do |format|
      format.html { render :index, locals: { pets: pets } }
      format.json { render json: pets.as_json(include: :sightings) }
    end
  end

  def show
    @similar_sightings = @pet.similar_sightings
  end

  def new
    @pet = current_user.pets.new
  end

  def create
    @pet = current_user.pets.new(pet_params)

    uploaded_photos = Array.wrap(params[:pet][:photos])
    valid_photos = uploaded_photos.reject(&:blank?)

    if valid_photos.blank?
      @pet.errors.add(:photos, "en az bir fotoğraf seçin ve tekrar deneyin")
      render :new, status: :unprocessable_entity
      return
    end

    main_photo = valid_photos.first
    temp_path = Rails.root.join('tmp', "pet_upload_#{Time.now.to_i}_#{main_photo.original_filename}")
    File.binwrite(temp_path, main_photo.read)

    begin
      service = BiometricAnalysisService.new(temp_path.to_s)
      result = service.call
    rescue BiometricAnalysisService::AnalysisError => e
      File.delete(temp_path) if File.exist?(temp_path)
      @pet.errors.add(:base, "Fotoğraf analizi başarısız oldu: #{e.payload['message']}")
      Rails.logger.warn("[PetsController] Biometric analysis failed: #{e.payload.inspect}")
      render :new, status: :unprocessable_entity
      return
    ensure
      File.delete(temp_path) if File.exist?(temp_path)
    end

    if result['status'] == 'success'
      embedding = result['face_embedding'] || result['embedding']
      if embedding.present?
        @pet.face_embedding = embedding
        
        # YAPAY ZEKA VERİLERİNİ DOĞRUDAN KAYDEDİYORUZ
        @pet.fur_color = result['renk'] if result['renk'].present?
        
        # YENİ VE KRİTİK SATIR: Kullanıcı formu boş bıraksa bile AI'ın bulduğu türü eziyoruz!
        @pet.species = result['tur'] if result['tur'].present? 
        
        Rails.logger.info "✅ [PetsController] İlan için yüz izi, renk ve tür bilgisi otonom olarak çıkarıldı."
      else
        @pet.errors.add(:base, "Fotoğraf analizi başarılı oldu ancak vektör alınamadı.")
        Rails.logger.warn "⚠️ [PetsController] İlan analizi sonucu vektör içermiyor: #{result.inspect}"
        render :new, status: :unprocessable_entity
        return
      end
    else
      @pet.errors.add(:base, "Fotoğraf analizi başarısız oldu: #{result['message']}")
      Rails.logger.warn "⚠️ [PetsController] İlan analizi başarısız oldu: #{result['message']}"
      render :new, status: :unprocessable_entity
      return
    end

    if @pet.save
      redirect_to pet_path(@pet), notice: "Kayıp ilanınız başarıyla oluşturuldu ve biyometrik veriler sisteme kaydedildi."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_pet
    @pet = Pet.find(params[:id])
  end

  def pet_params
    # Kullanıcıdan gelen parametreler alınıyor ancak AI verisi 'species' alanını ezecek
    params.require(:pet).permit(:name, :age, :breed, :species, :city, :district, :neighborhood, photos: [])
  end
end