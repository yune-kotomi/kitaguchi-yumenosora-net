Hotarugaike::Application.routes.draw do
  get 'profile/retrieve', :controller => :auth_tickets, :action => :show

  resources :openid_urls, :only => [:destroy]
  post 'openid_urls/login',
    :controller => :openid_urls, :action => :login
  get 'openid_urls/complete(/:service_id)',
    :controller => :openid_urls, :action => :complete

  get 'hatena/login' =>
    'openid_urls#hatena_authenticate'
  get 'hatena/complete' =>
    'openid_urls#hatena_complete'

  get 'openid_connect/authenticate' =>
    'openid_urls#openid_connect_authenticate'
  get 'openid_connect/callback' =>
    'openid_urls#openid_connect_complete'

  resources :services

  resource :profile, :only => [:new, :create, :show, :update]
  get 'profile/authenticate', :controller => :profiles, :action => :authenticate
  get 'profile/logout' => 'profiles#logout'

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
