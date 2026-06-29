# frozen_string_literal: true

# Wire engine concerns and overrides into host Mastodon classes during reload.
Rails.application.config.to_prepare do
  # Skip when running in the dummy app (Mastodon host classes not present)
  next unless defined?(Account)

  # --- Accounts / User ---
  Account.include(NewsmastMastodon::Concerns::AccountConcern)
  Account.include(NewsmastMastodon::Concerns::AccountSearchConcern)
  User.include(NewsmastMastodon::Concerns::OverrideChangedPassword)
  User.include(NewsmastMastodon::Concerns::UserConcern)
  User.prepend(NewsmastMastodon::Concerns::OverridePrepareNewUser)
  User::HasSettings.prepend(NewsmastMastodon::Concerns::UserSettingExtend)

  # --- Status / Feed / Notification / MediaAttachment / Tag ---
  Status.include(NewsmastMastodon::Concerns::StatusConcern)
  Feed.prepend(NewsmastMastodon::Concerns::FeedConcern)
  PublicFeed.prepend(NewsmastMastodon::Concerns::PublicFeedConcern)
  FeedManager.include(NewsmastMastodon::Concerns::FeedManagerConcern)
  FanOutOnWriteService.include(NewsmastMastodon::Concerns::FanOutOnWriteConcern)
  Tag.prepend(NewsmastMastodon::Concerns::TagConcern)
  Notification.prepend(NewsmastMastodon::Concerns::NotificationConcern)
  MediaAttachment.include(NewsmastMastodon::Concerns::MediaAttachmentConcern)

  # --- ActivityPub relay interception ---
  ActivityPub::Activity::Create.prepend(NewsmastMastodon::Overrides::ActivityCreateRelayExtension)

  # --- Service overrides ---
  SearchService.prepend(NewsmastMastodon::Overrides::SearchServiceExtension)
  AccountSearchService.prepend(NewsmastMastodon::Overrides::AccountSearchServiceExtension)
  NotifyService.prepend(NewsmastMastodon::Overrides::NotifyServiceExtension)
  AppSignUpService.prepend(NewsmastMastodon::Overrides::AppSignUpServiceExtension)
  RemoveStatusService.prepend(NewsmastMastodon::Overrides::RemoveStatusServiceExtension)
  BatchedRemoveStatusService.prepend(NewsmastMastodon::Overrides::BatchedRemoveStatusServiceExtension)
  PostStatusService.prepend(NewsmastMastodon::Overrides::PostStatusServiceExtension)
  PostStatusService.prepend(NewsmastMastodon::Concerns::DraftStatusService)
  ReblogService.prepend(NewsmastMastodon::Overrides::ReblogServiceExtension)
  UpdateStatusService.prepend(NewsmastMastodon::Overrides::UpdateStatusServiceExtension)
  ProcessHashtagsService.prepend(NewsmastMastodon::Concerns::ProcessHashtagsServiceExtension)
  TagSearchService.prepend(NewsmastMastodon::Concerns::TagSearchService)

  # --- Serializer / Validator overrides ---
  REST::CredentialAccountSerializer.prepend(Overrides::CredentialAccountSerializer)
  REST::StatusSerializer.include(LocalOnlyPosts::StatusSerializerExtension)
  REST::V1::InstanceSerializer.prepend(LongPost::InstanceSerializerExtension)
  REST::InstanceSerializer.prepend(LongPost::InstanceSerializerExtension)
  StatusLengthValidator.prepend(LongPost::StatusLengthValidatorPatch)

  # --- Filter / Controller overrides ---
  AccountStatusesFilter.prepend(NewsmastMastodon::Overrides::ExtendedAccountStatusesFilter)

  Api::V1::AccountsController.prepend(NewsmastMastodon::Concerns::AccountsCreation)
  Api::V1::Accounts::CredentialsController.prepend(NewsmastMastodon::Concerns::AccountsUpdate)
  Api::V1::StatusesController.prepend(NewsmastMastodon::Api::V1::StatusesControllerExtension)
  Api::V1::Accounts::StatusesController.prepend(NewsmastMastodon::Overrides::AccountStatusesControllerExtension)
  Api::V1::ScheduledStatusesController.prepend(NewsmastMastodon::Overrides::ScheduledStatusesController)
  Api::V1::NotificationsController.prepend(NewsmastMastodon::Overrides::NotificationV1ExtendedController)
  Api::V2::NotificationsController.prepend(NewsmastMastodon::Overrides::NotificationExtendedController)
  Api::V1::Timelines::HomeController.prepend(NewsmastMastodon::Overrides::HomeExtendedTimeline)
  Api::V1::Timelines::PublicController.prepend(NewsmastMastodon::Overrides::PublicExtendedTimeline)
  Api::V1::Timelines::ListController.prepend(NewsmastMastodon::Overrides::ListTimelineControllerExtension)
  Api::V1::Timelines::TagController.prepend(NewsmastMastodon::Overrides::TagTimelineControllerExtension)
  Api::V1::BookmarksController.prepend(NewsmastMastodon::Overrides::BookmarksControllerExtension)
  Api::V1::Trends::StatusesController.prepend(NewsmastMastodon::Overrides::TrendsStatusesControllerExtension)
  Api::V2::SearchController.prepend(NewsmastMastodon::Concerns::SearchControllerExtension)

  Auth::TokensController.prepend(NewsmastMastodon::Concerns::CustomAuthenticationBehavior) if Object.const_defined?("Auth::TokensController")
  OAuth::TokensController.prepend(NewsmastMastodon::Concerns::CustomAuthenticationBehavior) if Object.const_defined?("OAuth::TokensController")
  Auth::SessionsController.prepend(NewsmastMastodon::Concerns::CustomSessionBehavior) if Object.const_defined?("Auth::SessionsController")

  # --- Admin controllers: require authentication ---
  [ Admin::DashboardController, Admin::ReportsController ].each do |controller|
    controller.class_eval do
      before_action :authenticate_user!
    end
  end
end
