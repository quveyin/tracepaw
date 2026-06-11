class SightingsController < ApplicationController
  before_action :set_sighting, only: %i[show]

  def new
    @sighting = Sighting.new
  end

  def show
  end

  def create
    # Require photo for biometric analysis
    unless params[:sighting][:photo].present?
      @sighting = Sighting.new(sighting_params)
      @sighting.errors.add(:photo, "fotoğraf yüklemek zorunludur")
      render :new, status: :unprocessable_entity
      return
    end

    # Save uploaded photo temporarily
    photo = params[:sighting][:photo]
    temp_path = Rails.root.join('tmp', "upload_#{Time.now.to_i}_#{photo.original_filename}")
    File.binwrite(temp_path, photo.read)

    begin
      service = BiometricAnalysisService.new(temp_path.to_s)
      result = service.call
    rescue BiometricAnalysisService::AnalysisError => e
      File.delete(temp_path) if File.exist?(temp_path)
      @sighting = Sighting.new(sighting_params)
      @sighting.errors.add(:base, "Fotoğraf analizi başarısız: #{e.payload['message']}")
      Rails.logger.warn("[SightingsController] Biometric analysis failed: #{e.payload.inspect}")
      render :new, status: :unprocessable_entity
      return
    ensure
      File.delete(temp_path) if File.exist?(temp_path)
    end

    embedding = result['face_embedding'] || result['embedding']
    if embedding.blank?
      @sighting = Sighting.new(sighting_params)
      @sighting.errors.add(:base, "Fotoğraf analizi başarılı oldu ancak vektör alınamadı.")
      render :new, status: :unprocessable_entity
      return
    end

    @sighting = Sighting.new(
      city: params[:sighting][:city],
      district: params[:sighting][:district],
      neighborhood: params[:sighting][:neighborhood],
      description: params[:sighting][:description],
      latitude: params[:sighting][:latitude].presence&.to_f,
      longitude: params[:sighting][:longitude].presence&.to_f,
      seen_at: params[:sighting][:seen_at].presence || Time.current,
      face_embedding: embedding,
      fur_color: result['renk'],
      species: result['tur'] # YENİ EKLENEN KRİTİK SATIR: YOLO'nun bulduğu türü kaydediyoruz!
    )

    if @sighting.save
      # Attach uploaded photo to sighting record
      @sighting.photo.attach(photo) if photo.present?

      # Trigger matching job
      MatchMakerJob.perform_later(@sighting.id)
      redirect_to root_path, notice: "İhbar başarıyla kaydedildi! Eşleşme kontrolü yapılıyor..."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def nearby
    lat = params[:lat].to_f
    lng = params[:lng].to_f

    if lat == 0.0 || lng == 0.0
      render json: { error: "Please provide lat and lng parameters" }, status: :bad_request
      return
    end

    location = [lat, lng]
    time_limit = 48.hours.ago

    nearby_sightings = Sighting.near(location, 5, units: :km)
      .where("seen_at >= ?", time_limit)
      .where(pet_id: nil)
    render json: nearby_sightings
  end

  private

  def set_sighting
    @sighting = Sighting.find(params[:id])
  end

  def sighting_params
    params.require(:sighting).permit(:city, :district, :neighborhood, :description, :seen_at, :photo, :latitude, :longitude)
  end
end