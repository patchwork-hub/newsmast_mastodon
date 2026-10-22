# frozen_string_literal: true

namespace :newsmast_mastodon do
  namespace :auto_follow do
    desc "Import AUTO_FOLLOW_* environment settings into the dashboard for LOCAL_DOMAIN"
    task :import_env, [:dry_run] => :environment do |_task, args|
      local_domain = ENV["LOCAL_DOMAIN"].to_s.strip
      abort "LOCAL_DOMAIN must be set to import auto-follow settings." if local_domain.blank?

      unless ActiveRecord::Base.connection.data_source_exists?("patchwork_auto_follows") &&
             ActiveRecord::Base.connection.data_source_exists?("patchwork_auto_follow_accounts")
        abort "Auto-follow dashboard tables are missing. Run the dashboard migrations against the shared database first."
      end

      instance_name = local_domain.parameterize(separator: "")
      enabled = ENV["AUTO_FOLLOW_ENABLED"].to_s.casecmp("true").zero?
      handles = ENV["AUTO_FOLLOW_ACCOUNTS"].to_s.split(/\s*,\s*/).reject(&:blank?).uniq
      abort "AUTO_FOLLOW_ENABLED is true, but AUTO_FOLLOW_ACCOUNTS is empty." if enabled && handles.empty?
      dry_run_value = args[:dry_run].presence || ENV["DRY_RUN"]
      dry_run = ActiveModel::Type::Boolean.new.cast(dry_run_value)

      resolved_accounts = []
      skipped_account_details = []
      seen_account_ids = Set.new

      handles.each_with_index do |handle, index|
        target_account = begin
          ResolveAccountService.new.call(handle) || ResolveAccountService.new.call(handle, skip_webfinger: true)
        rescue StandardError => e
          detail = "#{handle} (resolution error: #{e.class})"
          skipped_account_details << detail
          puts "Skipped #{index + 1}/#{handles.size}: #{detail}"
          next
        end

        if target_account.nil?
          detail = "#{handle} (account not found)"
          puts "Skipped #{index + 1}/#{handles.size}: #{detail}"
          skipped_account_details << detail
        elsif seen_account_ids.add?(target_account.id)
          resolved_accounts << target_account
          puts "Resolved #{index + 1}/#{handles.size}: #{handle}"
        else
          detail = "#{handle} (duplicate account)"
          skipped_account_details << detail
          puts "Skipped #{index + 1}/#{handles.size}: #{detail}"
        end
      end

      puts "Summary: resolved=#{resolved_accounts.size}, skipped=#{skipped_account_details.size}, total=#{handles.size}."
      puts "Skipped accounts: #{skipped_account_details.join('; ')}." if skipped_account_details.any?
      if dry_run
        puts "DRY RUN: no dashboard changes were made."
        next
      end

      abort "No accounts were resolved. No dashboard changes were made." if enabled && resolved_accounts.empty?

      ActiveRecord::Base.transaction do
        auto_follow = NewsmastMastodon::AutoFollow.find_or_initialize_by(instance_name: instance_name)
        auto_follow.title = "Auto-follow for #{local_domain}" if auto_follow.new_record?
        auto_follow.enabled = enabled
        auto_follow.save!

        NewsmastMastodon::AutoFollowAccount.where(patchwork_auto_follow_id: auto_follow.id).delete_all
        resolved_accounts.each_with_index do |account, position|
          NewsmastMastodon::AutoFollowAccount.create!(
            patchwork_auto_follow_id: auto_follow.id,
            account_id: account.id,
            position: position
          )
        end
      end

      puts "Imported auto-follow settings for #{local_domain}: enabled=#{enabled}, accounts=#{resolved_accounts.size}."
    end
  end
end