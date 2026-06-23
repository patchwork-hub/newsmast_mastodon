# frozen_string_literal: true


module NewsmastMastodon
  class BanStatusService
    include Redisable
    include DatabaseHelper

    def check_and_ban_status(status)
      setting_filter_types = [ "Content filters", "Spam filters" ]

      @status = status

      with_read_replica do
        setting_filter_types.each do |setting_filter_type|
          # Build the redis key for each filter family.
          redis_key = "#{setting_filter_type.downcase.gsub(/\s+/, '_')}_banned_status_ids"
          server_setting = NewsmastMastodon::ServerSetting.find_by(name: setting_filter_type)
          next unless server_setting&.value

          filters = fetch_filters_from_all_keys(server_setting.name)
          active_filters = filters.map { |f| JSON.parse(f) }.select { |f| f["is_active"] }
          active_filters.each do |f|
            keyword = f["keyword"]
            filter_type = f["filter_type"].downcase

            # Check if the keyword matches in the account object
            # This will ban the account if the keyword is found in username, display_name, or note
            # This is done before checking hashtags or content to ensure account banning is prioritized
            check_and_ban_account(keyword)

            if filter_type == "hashtag" || filter_type == "both"
              tag_ids = @status.tags.where(name: keyword.downcase.gsub("#", "")).ids
              if tag_ids.present?
                # If the tag is banned, update its is_banned attribute to true
                # to trigger update_tags callback for elastic search
                with_primary do
                  Tag.where(id: tag_ids).find_each do |tag|
                    tag.update(listable: false, trendable: false)
                  end
                end
                redis.zadd(redis_key, @status.id, @status.id)
              end
            end

            if filter_type == "both" || filter_type == "content"
              include_keyword = @status.search_word_in_status(keyword)
              if include_keyword
                redis.zadd(redis_key, @status.id, @status.id)
              end
            end
          end
        end
      end

      # Combine banned status_ids both content & spam filters
      # And also remove if the records exceeded 400 limit
      combine_banned_status_ids(@status.id)
    end

    def keyword_matches_in_status?(status_id, community_id, filter_type)
      @status = Status.find(status_id)
      filter_keywords = NewsmastMastodon::CommunityFilterKeyword.where(patchwork_community_id: community_id, filter_type: filter_type)

      return false if filter_type == "filter_out" && filter_keywords.empty?

      return true if filter_type == "filter_in" && filter_keywords.empty?

      filter_keywords.any? do |keyword|
        if keyword.is_filter_hashtag
          search_term = keyword.keyword.downcase.strip
          @status.tags.where("LOWER(name) = ?", search_term).present?
        else
          @status.search_word_in_status(keyword.keyword)
        end
      end
    end

    def global_keyword_matches_in_status?(status_id, community_id, filter_type)
      @status = Status.find(status_id)

      cache_key = "global_filter_keywords_#{filter_type}"
      global_filter_keywords = Rails.cache.fetch(cache_key, expires_in: 24.hours) do
        NewsmastMastodon::CommunityFilterKeyword.where(patchwork_community_id: nil, filter_type: filter_type).to_a
      end

      return false if filter_type == "filter_out" && global_filter_keywords.empty?

      return true if filter_type == "filter_in" && global_filter_keywords.empty?

      global_filter_keywords.any? do |keyword|
        if keyword.is_filter_hashtag
          search_term = keyword.keyword.downcase.strip
          @status.tags.where("LOWER(name) = ?", search_term).present?
        else
          @status.search_word_in_status(keyword.keyword)
        end
      end
    end

    private

    def combine_banned_status_ids(status_id)
      banned_status_keys = [ "excluded_status_ids", "content_filters_banned_status_ids", "spam_filters_banned_status_ids" ]
      redis.zunionstore(banned_status_keys[0], [ banned_status_keys[1], banned_status_keys[2] ])

      # Trim the combined list if it exceeds 400 items
      banned_status_keys.each do |banned_status_key|
        if redis.zcard(banned_status_key) > 400
          redis.zremrangebyrank(banned_status_key, 0, -401)
        end
      end

      return true if redis.zscore("excluded_status_ids", status_id)
      false
    end

    def fetch_filters_from_all_keys(setting_name)
      # Get all possible key formats for the setting
      production_key = setting_name == "Spam filters" ? "spam_filters" : "content_filters"
      development_key = setting_name == "Spam filters" ? "channel:spam_filters" : "channel:content_filters"

      all_filters = []

      # Check production key format first
      production_filters = redis.hgetall(production_key).values
      if production_filters.any?
        all_filters.concat(production_filters)
      else
        # If production key is empty, check development/channel key format
        development_filters = redis.hgetall(development_key).values
        all_filters.concat(development_filters) if development_filters.any?
      end

      all_filters
    end

    def check_and_ban_account(keyword)
      # Normalize keyword: remove '#', convert to lowercase, and strip whitespace
      normalized_keyword = keyword.to_s.downcase.strip.gsub("#", "")
      return if normalized_keyword.blank?

      account = Account.find_by(id: @status.account_id)
      return unless account

      if account.is_banned
        return
      end

      with_primary do
        account = Account.find_by(id: @status.account_id)
        return unless account

        is_account_banned = account_contains_keyword?(account, normalized_keyword)
        if is_account_banned
          account.update(is_banned: true)
        end
      end
    end

    def account_contains_keyword?(account, keyword)
      return false unless account && keyword.present?

      # Create regex pattern for exact word matching
      # \b ensures word boundaries (beginning and end of word)
      word_pattern = /\b#{Regexp.escape(keyword)}\b/i

      # Safely check each field with null protection and exact word matching
      username_match = account.username&.match?(word_pattern)
      display_name_match = account.display_name&.match?(word_pattern)
      note_match = account_note(account)&.match?(word_pattern)

      # Return true if keyword is found in any field
      username_match || display_name_match || note_match
    end

    def account_note(account)
      if account.note&.include?("<") && account.note&.include?(">")
        # Strip HTML tags and normalize
        note_text = ActionView::Base.full_sanitizer.sanitize(account.note)
        note_lower = note_text.downcase.strip
      else
        # Pure string, no HTML sanitization needed
        note_lower = account.note.downcase.strip
      end

      note_lower
    end
  end
end
