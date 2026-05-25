Rails.application.routes.draw do
  root "home#index"

  mount ActionCable.server => "/cable"

  get "up" => "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  namespace :api do
    get "schema/:id", to: "schemas#show"
    resources :schemas, only: :show

    resources :lines, only: [ :index, :show ] do
      post :suspend, on: :member
      post :resume, on: :member
      post :enter_maintenance, on: :member
      post :exit_maintenance, on: :member
      post :weather, on: :member, action: :set_weather
      post :dispatch, on: :member, action: :dispatch_car

      scope module: :lines do
        resources :stations, only: :index do
          post :raise_alert, on: :member
          post :clear_alert, on: :member
          post :mark_crowded, on: :member
          post :close, on: :member
          post :reopen, on: :member
        end
        resources :cars, only: :index
      end
      resources :incidents, only: [ :index, :create ]
      resources :operation_events, only: :index
    end

    resources :cars, only: :show do
      post :dispatch, on: :member, action: :dispatch_car
    end

    resources :incidents, only: [ :index, :show, :update ] do
      post :acknowledge, on: :member
      post :resolve, on: :member
      resources :incident_comments, only: [ :index, :create ]
    end

    get "reports/daily", to: "reports#daily"
    post "scenarios/import", to: "scenarios#import"
  end

  get "*path", to: "home#index", constraints: ->(request) {
    !request.xhr? && !request.path.start_with?("/api", "/cable", "/assets", "/rails")
  }
end
