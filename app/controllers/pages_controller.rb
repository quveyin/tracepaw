class PagesController < ApplicationController
  def index
    # Sadece sisteme kaydedilen kayıp ilanlarını (pets) çekiyoruz.
    # İhbarlar (sightings) burada YER ALMIYOR.
    @lost_pets = Pet.where.not(latitude: nil, longitude: nil)
  end
end