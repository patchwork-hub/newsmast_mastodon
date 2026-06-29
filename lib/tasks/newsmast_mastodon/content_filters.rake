# frozen_string_literal: true

# Tasks for refreshing banned tags and accounts from keyword filters.

namespace :content_filters do
  desc "Check tags against keyword filters and update banned status"
  task update_banned_tags: :environment do
    NewsmastMastodon::BanTagWorker.perform_async
  end

  desc "Check accounts against keyword filters and update banned status"
  task update_banned_accounts: :environment do
    start_time = Time.current
    puts "Starting to check accounts against keyword filters at #{start_time}..."

    begin
      keyword_filters = NewsmastMastodon::KeywordFilter.all

      if keyword_filters.empty?
        puts "No keyword filters found. Exiting."
        return
      end

      puts "Found #{keyword_filters.count} keyword filters to check against"

      filter_keywords = Set.new(keyword_filters.pluck(:keyword).map do |keyword|
        keyword.to_s.downcase.strip.gsub("#", "")
      end.reject(&:blank?))

      puts "Normalized #{filter_keywords.size} unique keywords for matching"

      banned_count    = 0
      error_count     = 0
      processed_count = 0
      batch_size      = 1000

      total_accounts = Account.count
      puts "Checking #{total_accounts} accounts in batches of #{batch_size}..."

      Account.select(:id, :username, :display_name, :note, :is_banned).find_in_batches(batch_size: batch_size) do |account_batch|
        accounts_to_ban = []

        account_batch.each do |account|
          processed_count += 1

          begin
            next if account.is_banned

            matched_keyword = nil

            filter_keywords.each do |normalized_keyword|
              if account_contains_keyword?(account, normalized_keyword)
                matched_keyword = normalized_keyword
                break
              end
            end

            if matched_keyword
              accounts_to_ban << { id: account.id, username: account.username, keyword: matched_keyword }
              puts "Found account to ban: '#{account.username}' (ID: #{account.id}) - Matches: '#{matched_keyword}'"
            end
          rescue => e
            error_count += 1
            puts "Error processing account ID #{account.id}: #{e.message}"
            Rails.logger.error "Error in update_banned_accounts for account #{account.id}: #{e.message}\n#{e.backtrace.join("\n")}"
          end
        end

        if accounts_to_ban.any?
          begin
            account_ids = accounts_to_ban.map { |a| a[:id] }
            Account.where(id: account_ids).find_each do |account|
              matched_info = accounts_to_ban.find { |a| a[:id] == account.id }
              Rails.logger.info "#{'>' * 8}Account: #{account.id} (#{account.username}) has been banned due to keyword: #{matched_info[:keyword]}.#{'<' * 8}"
              account.update!(is_banned: true)
              banned_count += 1
            end
            puts "Batch updated #{accounts_to_ban.size} accounts to banned status"
          rescue => e
            puts "Error in batch update: #{e.message}"
            Rails.logger.error "Batch update error in update_banned_accounts: #{e.message}\n#{e.backtrace.join("\n")}"

            accounts_to_ban.each do |account_info|
              begin
                account = Account.find(account_info[:id])
                Rails.logger.info "#{'>' * 8}Account: #{account.id} (#{account.username}) has been banned due to keyword: #{account_info[:keyword]}.#{'<' * 8}"
                account.update!(is_banned: true)
                banned_count += 1
              rescue => ee
                error_count += 1
                puts "Error updating account ID #{account_info[:id]}: #{ee.message}"
                Rails.logger.error "Individual update error for account #{account_info[:id]}: #{ee.message}"
              end
            end
          end
        end

        puts "Processed #{processed_count}/#{total_accounts} accounts (#{(processed_count.to_f / total_accounts * 100).round(2)}%)"
      end

      duration = (Time.current - start_time).round(2)

      puts "\n#{'=' * 50}"
      puts "SUMMARY:"
      puts "Total accounts processed: #{processed_count}"
      puts "Accounts updated to banned: #{banned_count}"
      puts "Errors encountered: #{error_count}"
      puts "Duration: #{duration} seconds"
      puts "Average: #{(processed_count.to_f / duration).round(2)} accounts/second"
      puts "=" * 50
    rescue => e
      puts "Fatal error in update_banned_accounts: #{e.message}"
      Rails.logger.error "Fatal error in update_banned_accounts: #{e.message}\n#{e.backtrace.join("\n")}"
      raise
    end
  end

  desc "Check accounts against keyword filters and show matches without updating"
  task preview_banned_accounts: :environment do
    start_time = Time.current
    puts "Previewing accounts that would be banned..."

    keyword_filters = NewsmastMastodon::KeywordFilter.all

    if keyword_filters.empty?
      puts "No keyword filters found. Exiting."
      return
    end

    puts "Found #{keyword_filters.count} keyword filters:"
    keyword_filters.each { |filter| puts "  - '#{filter.keyword}' (#{filter.filter_type})" }
    puts ""

    filter_keywords = Set.new(keyword_filters.pluck(:keyword).map do |keyword|
      keyword.to_s.downcase.strip.gsub("#", "")
    end.reject(&:blank?))

    puts "Normalized #{filter_keywords.size} unique keywords for matching\n"

    matches         = []
    processed_count = 0
    error_count     = 0

    Account.select(:id, :username, :display_name, :note, :is_banned).find_in_batches(batch_size: 1000) do |account_batch|
      account_batch.each do |account|
        processed_count += 1

        begin
          matched_keyword = nil
          filter_keywords.each do |normalized_keyword|
            if account_contains_keyword?(account, normalized_keyword)
              matched_keyword = normalized_keyword
              break
            end
          end

          matches << { account: account, keyword: matched_keyword, current_banned: account.is_banned } if matched_keyword
        rescue => e
          error_count += 1
          puts "Error processing account ID #{account.id}: #{e.message}"
          Rails.logger.error "Error in preview_banned_accounts for account #{account.id}: #{e.message}"
        end
      end

      puts "Processed #{processed_count} accounts..." if processed_count % 5000 == 0
    end

    matches.sort_by! { |m| [ m[:current_banned] ? 0 : 1, m[:account].username ] }

    puts "\nFound #{matches.count} accounts that match keyword filters:"

    display_limit = 100
    matches.first(display_limit).each do |match|
      status = match[:current_banned] ? "[ALREADY BANNED]" : "[WOULD BE BANNED]"
      puts "  #{status} Account: '#{match[:account].username}' (ID: #{match[:account].id}) - Matches: '#{match[:keyword]}'"
    end

    if matches.count > display_limit
      puts "  ... and #{matches.count - display_limit} more matches (showing first #{display_limit})"
    end

    new_bans       = matches.reject { |m| m[:current_banned] }.count
    already_banned = matches.select { |m| m[:current_banned] }.count

    duration = (Time.current - start_time).round(2)
    puts "\n#{'=' * 50}"
    puts "PREVIEW SUMMARY:"
    puts "Total accounts processed: #{processed_count}"
    puts "Total matches found: #{matches.count}"
    puts "Already banned: #{already_banned}"
    puts "Would be newly banned: #{new_bans}"
    puts "Errors encountered: #{error_count}"
    puts "Duration: #{duration} seconds"
    puts "=" * 50
  end

  desc "Reset banned status for all accounts (use with caution)"
  task reset_banned_accounts: :environment do
    puts "WARNING: This will reset is_banned to false for ALL accounts!"
    puts "Type 'CONFIRM' to proceed:"

    input = $stdin.gets.chomp
    if input == "CONFIRM"
      start_time = Time.current
      puts "Resetting banned status for all accounts..."

      count = Account.where(is_banned: true).count
      puts "Found #{count} banned accounts to reset"

      Account.where(is_banned: true).find_in_batches(batch_size: 1000) do |batch|
        batch.each { |account| account.update!(is_banned: false) }
        puts "Reset #{batch.size} accounts..."
      end

      duration = (Time.current - start_time).round(2)
      puts "Finished! Reset #{count} accounts in #{duration} seconds."
    else
      puts "Operation cancelled."
    end
  end

  # Helper available to all tasks in this file
  def account_contains_keyword?(account, keyword)
    return false unless account && keyword.present?

    normalized_keyword = keyword.to_s.downcase.strip.gsub("#", "")
    word_pattern       = /\b#{Regexp.escape(normalized_keyword)}\b/i

    account.username&.match?(word_pattern) ||
      account.display_name&.match?(word_pattern) ||
      account.note&.match?(word_pattern)
  end
end
