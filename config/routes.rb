# frozen_string_literal: true

# Engine API routes for account, conversation, timeline, local-only post,
# draft/status, relay, and webhook features.
NewsmastMastodon::Engine.routes.draw do
  # GEM_SPLIT[UI-03]: DISABLED at cutover (2026-10-13) — these routes are now
  # served by patchwork_extensions (Gem B), which the host mounts via
  # `gem "patchwork_extensions", path: "../patchwork_extensions"`. Remove this
  # block and the Gem A controller/initializer after host verification passes.
  # Deep link well-known routes (no auth required)
  # scope path: ".well-known" do
  #   get "apple-app-site-association", to: "well_known/deep_links#apple_app_site_association",
  #       as: :apple_app_site_association
  #   get "assetlinks.json", to: "well_known/deep_links#asset_links",
  #       as: :asset_links
  # end

  namespace :api, defaults: { format: "json" } do
    namespace :v1 do
      # --- accounts ---
      resources :custom_passwords, only: %i[create update] do
        collection do
          post :verify_otp, to: "custom_passwords#verify_otp"
          get  :request_otp, to: "custom_passwords#request_otp"
          post :change_password, to: "custom_passwords#change_password"
          post :change_email, to: "custom_passwords#change_email"
          post :bristol_cable_sign_in, to: "custom_passwords#bristol_cable_sign_in"
        end
      end

      resources :notification_tokens, only: [ :create ] do
        collection do
          post :revoke_token, to: "notification_tokens#revoke_notification_token"
          post :update_mute, to: "notification_tokens#update_mute"
          get  :get_mute_status, to: "notification_tokens#get_mute_status"
          delete "/reset_device_tokens/:platform_type", to: "notification_tokens#reset_device_tokens"
        end
      end

      # GEM_SPLIT[AUTH-06]: DISABLED at cutover (2026-10-13) — these routes are
      # now served by patchwork_extensions (Gem B), which the host mounts via
      # `gem "patchwork_extensions", path: "../patchwork_extensions"`. Remove this
      # block and the Gem A controller after host verification passes.
      # resources :user_locales, only: [ :create ]

      # GEM_SPLIT[COMMUNITY-03]: DISABLED at cutover (2026-10-08) — these routes
      # are now served by patchwork_extensions (Gem B), which the host mounts via
      # `gem "patchwork_extensions", path: "../patchwork_extensions"`. Remove this
      # block and the Gem A controller/data after host verification passes.
      # resources :channels, only: [] do
      #   collection do
      #     get :starter_packs_channels
      #   end
      #   member do
      #     get :starter_packs_detail
      #   end
      # end
      post "civicrm_role_assign", to: "civicrm_role_assignments#create"

      resources :channels, only: [] do
        collection do
          get :starter_packs_channels
        end
        member do
          get :starter_packs_detail
        end
      end

      namespace :patchwork do
        resources :alttext_settings, only: [ :index ] do
          collection do
            post "/alttext", to: "alttext_settings#change_alttext_setting"
          end
        end
        resources :email_settings, only: [ :index ] do
          collection do
            post "/notification", to: "email_settings#email_notification"
          end
        end

        # GEM_SPLIT[AUTH-06]: DISABLED at cutover (2026-10-13) — this route is
        # now served by patchwork_extensions (Gem B). Remove this block and the
        # Gem A controller after host verification passes.
        # resources :account_deletion, only: [ :destroy ]

        # --- status reactions ---
        resources :statuses, only: [] do
          resources :reactions, only: [ :update, :destroy ],
            controller: "status_reactions"
        end

        # GEM_SPLIT[CONV-01]: DISABLED at cutover (2026-10-09) — these routes are
        # now served by patchwork_extensions (Gem B), which the host mounts via
        # `gem "patchwork_extensions", path: "../patchwork_extensions"`. Remove
        # this block and the Gem A controller after host verification passes.
        # resources :conversations, only: [] do
        #   collection do
        #     get  :check_conversation
        #     post :read_all
        #   end
        # end
      end

      # GEM_SPLIT[AUTH-06]: DISABLED at cutover (2026-10-13) — this route is
      # now served by patchwork_extensions (Gem B). Remove this line and the
      # Gem A controller after host verification passes.
      # post "/delete_account", to: "accounts#delete_account"

      namespace :accounts do
        get  "leicester_notification", to: "patchwork_settings#leicester_news_notification"
        post "leicester_notification", to: "patchwork_settings#update_leicester_news_notification"

        # GEM_SPLIT[CMS-02]: DISABLED at cutover (2026-10-15) — this route is
        # now served by patchwork_extensions (Gem B). Remove this line and the
        # Gem A controller after host verification passes.
        # post "subscribe_leicester", to: "ghost_subscriptions#manage_subscription"

        # Receive new article notifications
        get  "article_notifications", to: "patchwork_settings#article_notifications"
        post "article_notifications", to: "patchwork_settings#update_article_notifications"
      end

      # --- custom_feeds ---
      namespace :timelines do
        get "@:username/feed", to: "feeds#show", as: :custom_feed

        # GEM_SPLIT[FEED-02]: DISABLED at cutover (2026-10-16) — this route is
        # now served by patchwork_extensions (Gem B), which the host mounts via
        # `gem "patchwork_extensions", path: "../patchwork_extensions"`. Remove
        # this line and the Gem A controller after host verification passes.
        # get "for_you_custom_timeline", to: "for_you_custom_timeline#show", as: :for_you_custom_timeline

        # Instances timeline (home + selected relay domains)
        # Domain can be omitted, single, or multiple via query string:
        #   /api/v1/timelines/instances_timeline
        #   /api/v1/timelines/instances_timeline?domain=mastodon.social
        #   /api/v1/timelines/instances_timeline?domain=mastodon.social,mastodon.beer
        get "instances_timeline", to: "instances_timeline#show", as: :instances_timeline
      end

      # GEM_SPLIT[BOOST-01]: DISABLED at cutover (2026-10-28) — these routes are
      # now served by patchwork_extensions (Gem B), which the host mounts via
      # `gem "patchwork_extensions", path: "../patchwork_extensions"`. Remove
      # this block and the Gem A controller after the verification window.
      # namespace :custom_statuses do
      #   post "add_custom_boost_bot_status",    to: "custom_boost_bot_status#add_custom_boost_bot_status",    as: :add_custom_boost_bot_status
      #   post "remove_custom_boost_bot_status", to: "custom_boost_bot_status#remove_custom_boost_bot_status", as: :remove_custom_boost_bot_status
      # end

      # --- local_only_posts ---
      resources :local_only_posts, only: [] do
        collection do
          get :getLocalOnlySetting
        end
      end

      # --- posts ---
      resources :drafted_statuses, only: %i[create index show update destroy] do
        member do
          post :publish
        end
      end

      # GEM_SPLIT[MEDIA-02]: Migrated to patchwork_extensions (Gem B); Gem B
      # serves GET /api/v1/utilities/link_preview. Remove after the
      # verification window.
      # resources :utilities, only: [] do
      #   collection do
      #     get :link_preview
      #   end
      # end

      post   "patchwork/relays",     to: "relays#create"
      delete "patchwork/relays/:id", to: "relays#destroy"

      post "ghost_webhooks",     to: "webhooks#handle_ghost"
      post "wordpress_webhooks", to: "webhooks#handle_wordpress"

      # Inbound cross-instance push notifications from a trusted partner instance
      post "cross_instance_push", to: "cross_instance_push#create"
    end
  end
end
