# frozen_string_literal: true


module NewsmastMastodon
  class AutoFollowDefaultAccountsService < BaseService
    def call(source_account)
      return unless source_account.local?

      auto_follow = dashboard_auto_follow
      if auto_follow
        return unless auto_follow.enabled?

        auto_follow.auto_follow_accounts.each do |membership|
          follow_account_record(source_account, membership.account)
        end
        return
      end

      follow_environment_accounts(source_account)
    end

    private

    def dashboard_auto_follow
      return unless ActiveRecord::Base.connection.data_source_exists?("patchwork_auto_follows")

      auto_follows = NewsmastMastodon::AutoFollow.includes(auto_follow_accounts: :account).to_a
      select_dashboard_auto_follow(auto_follows)
    end

    def select_dashboard_auto_follow(auto_follows)
      instance_name = ENV.fetch("LOCAL_DOMAIN", "").parameterize(separator: "")
      auto_follows.find { |auto_follow| auto_follow.instance_name == instance_name }
    end

    def follow_environment_accounts(source_account)
      return unless ENV["AUTO_FOLLOW_ENABLED"].to_s.casecmp("true").zero?

      auto_follow_accounts = ENV["AUTO_FOLLOW_ACCOUNTS"].presence&.split(/\s*,\s*/)&.reject(&:blank?) || []
      auto_follow_accounts.each do |acct|
        follow_account(source_account, acct)
      end
    end

    def follow_account_record(source_account, target_account)
      FollowService.new.call(source_account, target_account, bypass_locked: true, bypass_limit: true)
    rescue StandardError => e
      Rails.logger.error "Failed to auto-follow #{target_account.acct} for #{source_account.acct}: #{e.message}"
    end

    def follow_account(source_account, target_acct)
      target_account = ResolveAccountService.new.call(target_acct)
      if target_account.nil?
        target_account = ResolveAccountService.new.call(target_acct, skip_webfinger: true)
      end
      if target_account.nil?
        Rails.logger.warn "Auto-follow target #{target_acct} could not be resolved for #{source_account.acct}"
        return
      end

      FollowService.new.call(source_account, target_account, bypass_locked: true, bypass_limit: true)
    rescue StandardError => e
      Rails.logger.error "Failed to auto-follow #{target_acct} for #{source_account.acct}: #{e.message}"
    end
  end
end
