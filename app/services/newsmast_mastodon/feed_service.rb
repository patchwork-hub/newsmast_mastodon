# frozen_string_literal: true


module NewsmastMastodon
  class FeedService
    include Redisable

    def initialize(account = nil)
      @account = account
    end

    def server_setting?
      content_filters = NewsmastMastodon::ServerSetting.where(name: "Content filters").last
      return false unless content_filters
      content_filters.value
    end

    def excluded_status_ids
      content_filter = NewsmastMastodon::ServerSetting.where(name: "Content filters").last
      spam_filter = NewsmastMastodon::ServerSetting.where(name: "Spam filters").last

      return [] unless content_filter && spam_filter

      if content_filter.value && spam_filter.value
        redis.zrange("excluded_status_ids", 0, -1)
      elsif content_filter.value
        redis.zrange("content_filters_banned_status_ids", 0, -1)
      elsif spam_filter.value
        redis.zrange("spam_filters_banned_status_ids", 0, -1)
      else
        []
      end
    end

    def server_setting_federation?
      NewsmastMastodon::ServerSetting.where(name: "Threads", value: true).exists? || NewsmastMastodon::ServerSetting.where(name: "Bluesky", value: true).exists? if @account
    end

    def federation_filter_by_server_setting
      Status.domain_filter_by_server_setting_scope(@account) if @account
    end
  end
end
