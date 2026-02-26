# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  namespace :admin do
    resources :products do
      collection do
        get :check_sku
      end
    end
  end

  namespace :api do
    namespace :moysklad do
      resources :webhooks, only: :create
    end
  end

  namespace :public do
    get 'images/:image_id', to: 'images#show'
  end

  namespace :integrations do
    namespace :insales do
      post :external_discount, to: 'external_discounts#create'
    end
  end

  # Defines the root path route ("/")
  root 'admin/products#index'
end
