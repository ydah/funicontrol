Rails.application.routes.draw do
  root "home#index"

  mount ActionCable.server => "/cable"

  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    get "schema/:id", to: "schemas#show"
    resources :schemas, only: :show

    resources :lines, only: [ :index, :show ] do
      post :suspend, on: :member
      post :resume, on: :member
      post :dispatch, on: :member, action: :dispatch_car

      scope module: :lines do
        resources :stations, only: :index do
          post :raise_alert, on: :member
          post :clear_alert, on: :member
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
      post :resolve, on: :member
      resources :incident_comments, only: [ :index, :create ]
    end
  end

  get "*path", to: "home#index", constraints: ->(request) {
    !request.xhr? && !request.path.start_with?("/api", "/cable", "/assets", "/rails")
  }
end
