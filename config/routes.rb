Rails.application.routes.draw do
  get 'revolut_transactions/index'
  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'
  resources :users
  get 'article_stats/index'
  resources :article_categories
  resources :tax_codes
  resources :entries, only: [:index, :update]
  get 'accounting', to: 'accounting#index'
  get 'accounting/settings', to: 'accounting#settings'
  post 'accounting/settings', to: 'accounting#update_settings'
  get 'accounting/bexio_auth', to: 'accounting#bexio_auth'
  get 'accounting/bexio_callback', to: 'accounting#bexio_callback'
  post 'accounting/import_accounts', to: 'accounting#import_accounts'
  post 'accounting/import_tax_codes', to: 'accounting#import_tax_codes'
  post 'accounting/export_bexio', to: 'accounting#export_bexio'
  post 'accounting/create_booking', to: 'accounting#create_booking'
  post 'accounting/create_transaction_booking', to: 'accounting#create_transaction_booking'
  resources :revolut_transactions, only: [:index, :update] do
    collection do
      post :import
      post :export
    end
  end
  resources :stock_transfers, only: [:index, :create]
  resources :stock_orders, only: [:index]
  resources :inventories do
    member do
      post :update_line
      post :complete
      get :report
    end
  end
  resources :locations do
    member do
      post :add_stock
    end
  end
  resources :sections, only: [:edit, :update] do
    member do
      post :add_article
      delete :remove_article
    end
  end

  root "cash_registers#index"

  resources :cash_registers do
    member do
      get :transactions
      get :cash_count
      post :save_cash_count
    end
  end
  resources :articles
  resources :pos, controller: 'pos', only: [:index, :show], as: 'pos' do
    member do
      post :add_item
      post :add_variant_item
      patch :update_item_quantity
      delete :remove_item
      post :checkout
      get :payment
      post :process_payment
      get :add_free_price_item
      post :save_free_price_item
      get :withdraw_cash
      post :process_withdrawal
      post :park_order
      post :restore_order
      post :update_item_discount
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
