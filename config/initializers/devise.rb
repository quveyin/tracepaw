require 'devise/orm/active_record'

Devise.setup do |config|
  config.mailer_sender = 'please-change-me-at-config-initializers-devise@example.com'
  config.secret_key = Rails.application.credentials.secret_key_base if Rails.application.respond_to?(:credentials)
  config.navigational_formats = ['*/*', :html, :turbo_stream]
end
