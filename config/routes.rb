# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
Rails.application.routes.draw do
  mount RailsAdmin::Engine => '/admin', :as => 'rails_admin'

  get 'home/index'

  devise_for :users,
             path_names: { sign_in: 'login', sign_out: 'logout', confirmation: 'confirm', sign_up: 'new' },
             controllers: {
               registrations: 'registrations',
               sessions: 'sessions',
               confirmations: 'confirmations',
               passwords: 'passwords'
             }

  resource :users, only: [] do
    get :join_team, on: :member
  end

  # Saying resources :users do causes all routes for the team to be generated.
  # By saying only: [] it keeps only the routes specified in the do block to be generated.
  resources :teams, except: %i[destroy] do
    # Different route for inviting a user to the team.
    member do
      patch :invite
      put :invite
      get :summary
    end
    # Custom route for accepting user invites.
    resources :user_invites, only: [:destroy] do
      get :accept, on: :member
    end
    resources :user_requests, only: %i[create destroy] do
      get :accept, on: :member
    end
    resources :users, only: [] do
      delete :leave_team
      get :promote
    end
  end

  # game
  resource :game, only: %i[show] do
    get :completion_certificate_template
    get :privacy_notice
    get :summary
    get :terms_of_service
    resources :messages, only: [:index]
    resources :achievements, only: [:index]
    resources :divisions, only: [:index]
    resources :flags, only: [:index] # Prank route!
    resources :challenges, only: %i[show update]
    resources :teams, only: [] do
      resources :challenges, only: %i[show update]
    end
  end

  resources :file_submissions, only: [] do
    member do
      get :submitted_bundle
    end
  end

  root to: 'home#index'
end
# rubocop:enable Metrics/BlockLength
