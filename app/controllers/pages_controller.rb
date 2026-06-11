class PagesController < ApplicationController
  def index
    @lost_pets = Pet.where.not(latitude: nil, longitude: nil)
  end
end