# frozen_string_literal: true


module NewsmastMastodon
  class GhostNotificationService < BaseService
    include NonChannelHelper

    def call(ghost_post_data)
      tokens_table = NewsmastMastodon::NotificationToken.table_name
      settings_table = NewsmastMastodon::PatchworkSetting.table_name
      @notification_tokens = NewsmastMastodon::NotificationToken
        .joins("INNER JOIN #{settings_table} ON #{settings_table}.account_id = #{tokens_table}.account_id")
        .where("#{settings_table}.settings ->> 'leicester_notification' = ?", "true")
        .select("#{tokens_table}.*")

      app_title = ENV["GHOST_NOTIFICATION_SENDER_NAME"] || "Development Patchwork"
      body = ghost_post_data["title"].truncate_words(8)
      data = {
        noti_type: "ghost_articles",
        article_id: ghost_post_data["article_id"]
      }

      # for ios & android
      @notification_tokens.where.not(platform_type: "huawei").find_each do |token_record|
        NewsmastMastodon::FirebaseNotificationService.send_notification(token_record.notification_token, app_title, body, data)
      end
    end
  end
end
