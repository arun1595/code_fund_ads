require "sidekiq/web"
Sidekiq::Web.set :session_secret, Rails.application.credentials[:secret_key_base]

Rails.application.routes.draw do
  root to: "pages#index"

  authenticate :user, lambda { |user| AuthorizedUser.new(user).can_admin_system? } do
    mount Sidekiq::Web => "/sidekiq"
  end

  devise_for :users, controllers: {
    sessions: "sessions",
    invitations: "invitations",
  }

  resource :contact, only: [:show, :create]
  resources :dashboards, only: [:show], as: :dashboard
  resources :campaign_searches, only: [:create, :update, :destroy]
  resources :property_searches, only: [:create, :update, :destroy]
  resources :user_searches, only: [:create, :update, :destroy]
  resources :creative_searches, only: [:create, :update, :destroy]
  resource :creative_options, only: [:show]

  # polymorphic based on: app/models/concerns/imageable.rb
  scope "/imageables/:imageable_gid/" do
    resources :image_searches, only: [:create, :update, :destroy]
    resources :images, except: [:show]
  end

  resources :versions, only: [:show, :update]
  resources :comments, only: [:create, :destroy]

  resources :campaigns
  scope "/campaigns/:campaign_id" do
    resource :campaign_targeting, only: [:show], path: "/targeting"
    resource :campaign_budget, only: [:show], path: "/budget"
    resource :campaign_dashboards, only: [:show], path: "/overview"
    resources :campaign_properties, only: [:index], path: "/properties"
    resources :versions, only: [:index], as: :campaign_versions, path: "/revisions"
    resources :comments, only: [:index], as: :campaign_comments
    resources :events, only: [:index], as: :campaign_events
  end

  resources :creatives
  scope "/creatives/:creative_id" do
    resources :events, only: [:index], as: :creaive_events
  end

  # this action should semantically be a `create`,
  # but we are using `show` because it renders the pixel image that creates the impression record
  resources :impressions, only: [:show], path: "/display", constraints: ->(req) { req.format == :gif }
  scope "/impressions/:impression_id" do
    # this action should semantically be a `create`,
    # but we are using `show` because its also a pass through that redirects to the campaign url
    resource :advertisement_clicks, only: [:show], path: "/click"
  end

  resources :properties do
    resources :property_screenshots, only: [:update]
  end
  scope "/properties/:property_id" do
    resource :property_keywords, only: [:show], path: "/keywords"
    resource :property_earnings, only: [:show], path: "/earnings"
    resource :property_dashboards, only: [:show], path: "/overview"
    resources :property_campaigns, only: [:index], path: "/campaigns"
    resources :versions, only: [:index], as: :property_versions, path: "/revisions"
    resource :advertisements, only: [:show], path: "/funder", constraints: ->(req) { req.format == :js }
    resource :advertisement_previews, only: [:show], path: "/preview" if Rails.env.development?
    resources :comments, only: [:index], as: :property_comments
    resources :events, only: [:index], as: :property_events
  end

  resources :templates
  resources :themes
  resources :users
  resource :user_passwords, only: [:edit, :update], path: "/password"

  scope "/users/:user_id" do
    resources :campaigns, only: [:index], as: :user_campaigns
    resources :properties, only: [:index], as: :user_properties
    resources :creatives, only: [:index], as: :user_creatives
    resources :versions, only: [:index], as: :user_versions
    resources :comments, only: [:index], as: :user_comments
    resources :events, only: [:index], as: :user_events
    resource :identicon, only: [:show], format: :png, as: :user_identicon, path: "/identicon.png"
    resource :impersonations, only: [:update], as: :user_impersonation, path: "/impersonate"
  end
  get "/stop_user_impersonation", to: "impersonations#destroy", as: :stop_user_impersonation

  resource :newsletter_subscription, only: [:create]
  resources :advertisers, only: [:index, :create]
  resources :publishers, only: [:index, :create]

  # IMPORTANT: leave as last route so it doesn't override others
  resources :pages, only: [:show], path: "/"
end
