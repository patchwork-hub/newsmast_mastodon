# frozen_string_literal: true

module NewsmastMastodon
  module Concerns
    module OverridePrepareNewUser
      def prepare_new_user!
        NewsmastMastodon::AutoFollowDefaultAccountsService.new.call(account)
        BootstrapTimelineWorker.perform_async(account_id)
        ActivityTracker.increment("activity:accounts:local")
        ActivityTracker.record("activity:logins", id)
        if ENV["WELCOME_EMAIL_DISABLED"].blank? || ENV["WELCOME_EMAIL_DISABLED"].to_s.downcase != "true"
          UserMailer.welcome(self).deliver_later(wait: 1.hour)
        end
        TriggerWebhookWorker.perform_async("account.approved", "Account", account_id)
      end
    end
  end
end
