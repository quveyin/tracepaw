class SightingsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    sighting = Sighting.new(sighting_params)

    if sighting.save
      MatchMakerJob.perform_later(sighting.id)

      render json: { mesaj: "Veri başarıyla kaydedildi!", veri: sighting }, status: :created
    else
      render json: { hata: "Kaydedilemedi!" }, status: :unprocessable_entity
    end
  end

  def nearby
    lat = params[:lat].to_f
    lng = params[:lng].to_f

    if lat == 0.0 || lng == 0.0
      render json: { hata: "Lütfen URL'de lat ve lng parametrelerini gönderin!" }, status: :bad_request
      return
    end

    aranan_konum = [lat, lng]
    zaman_siniri = 48.hours.ago

    yakin_ihbarlar = Sighting.near(aranan_konum, 5, units: :km)
      .where("seen_at >= ?", zaman_siniri)
      .where(pet_id: nil)
    render json: yakin_ihbarlar
  end

  private

  def sighting_params
    params.require(:sighting).permit(:pet_id, :latitude, :longitude, :description, :seen_at, face_embedding: [])
  end
end