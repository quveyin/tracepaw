Rails.application.routes.draw do
  get '/pets', to: 'pets#index'
  post '/sightings', to: 'sightings#create' 
  get '/sightings/nearby', to: 'sightings#nearby'
  root 'pages#index'
end