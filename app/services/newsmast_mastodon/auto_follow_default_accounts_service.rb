# frozen_string_literal: true


module NewsmastMastodon
  class AutoFollowDefaultAccountsService < BaseService
    def call(source_account)
      return unless source_account.local?

      auto_follow_accounts = ENV["AUTO_FOLLOW_ACCOUNTS"].presence&.split(/\s*,\s*/)&.reject(&:blank?) || []
      auto_follow_accounts.each do |acct|
        follow_account(source_account, acct)
      end
    end

    private

    def follow_account(source_account, target_acct)
      target_account = ResolveAccountService.new.call(target_acct)
      if target_account.nil?
        target_account = ResolveAccountService.new.call(target_acct, skip_webfinger: true)
      end
      return if target_account.nil?

      FollowService.new.call(source_account, target_account, bypass_locked: true, bypass_limit: true)
    rescue StandardError => e
      Rails.logger.error "Failed to auto-follow #{target_acct} for #{source_account.acct}: #{e.message}"
    end
  end
end
