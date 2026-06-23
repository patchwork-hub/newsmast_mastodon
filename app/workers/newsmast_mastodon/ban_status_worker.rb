# frozen_string_literal: true


module NewsmastMastodon
  class BanStatusWorker
    include Sidekiq::Worker

    sidekiq_options queue: "default", retry: 0

    def perform(status_id)
      status = Status.includes(:account, :tags).find_by(id: status_id)
      return unless status

      is_status_banned = NewsmastMastodon::BanStatusService.new.check_and_ban_status(status)

      if is_status_banned
        attrs = {
          is_banned: is_status_banned,
          updated_at: Time.current
        }
        if status.local?
          attrs.merge!(sensitive: true, spoiler_text: "Sensitive content!!!")
        end
        status.update!(attrs)
      else
        NewsmastMastodon::ReblogChannelsService.new.call(status) if reblog_enabled?(is_status_banned)
      end
    end

    private

    def reblog_enabled?(is_status_banned)
      ((ENV.fetch("MAIN_CHANNEL", nil) != "false" && ENV.fetch("MAIN_CHANNEL", nil) != nil) ||
      (ENV.fetch("BOOST_BOT_ENABLED", nil) != "false" && ENV.fetch("BOOST_BOT_ENABLED", nil) != nil)) &&
        !is_status_banned
    end
  end
end
