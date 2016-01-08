Rails.application.routes.draw do

  resources :reports, only: :index, defaults: { format: 'html' }
  resources :purchases, only: [:create, :update]
  resources :plans, only: [:create, :destroy, :index]
  resources :bank_accounts, only: [:create, :destroy, :update]
  resources :subscribe, only: [:update,:destroy]

  resources :pending_goals, only: :index
  resources :fundraising_goals

  resources :merchants, only: [:index, :show], path: 'orgs'
  
  resources :notifications, only: [:create, :destroy]
  resources :contact_us
  
  devise_for :users
  resources :users, only: [:update]

  get 'donate' => 'donate#donate'
  get 'terms' => 'home#terms'
  get 'give' => 'home#give'
  get 'donation_history' => 'home#donation_history'

  put 'approve_goal' => 'pending_goals#approve_goal'
  put 'approve_account' => 'merchants#approve_account'
  get 'pending' => 'merchants#pending'
  get 'approved_accounts' => 'merchants#approved_accounts'
  put 'cancel_donation_plan' => 'fundraising_goals#cancel_donation_plan'
  put 'create_user' => 'donate#create_user'
  put 'give_action' => 'home#give_action'
  put 'twilio/text_blast' => 'twilio#text_blast'
  put 'twilio/email_blast' => 'twilio#email_blast'
  
  post 'notifications/twilio' => 'notifications#twilio'
  post 'notifications/import_numbers' => 'notifications#import_numbers'
  post 'notifications/import_emails' => 'notifications#import_emails'
  post 'notifications/remove_text' => 'notifications#remove_text'
  post 'notifications/remove_email' => 'notifications#remove_email'
  post 'notifications/stop_notifications' => 'notifications#stop_notifications'

  root to: 'home#home'
end
