class MatchMailer < ApplicationMailer
  default from: 'noreply@tracepaw.com'

  def match_found
    @sighting = params[:sighting]
    @pet = params[:pet]

    mail(
      to: @pet.user.email,
      subject: "🐾 Müjde! Kayıp dostunuza benzeyen bir hayvan bulundu!"
    )
  end
end
