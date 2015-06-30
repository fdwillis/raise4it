Rails.application.routes.draw do
  resources :charges, only: [:new, :create]
  resources :products
  root to: 'products#index'
  devise_for :users
  resources :users, only: [:update]
end
