# frozen_string_literal: true


module NewsmastMastodon
  class ReblogChannelsWorker
    include Sidekiq::Worker
    sidekiq_options queue: "default", retry: false, dead: true

    def perform(status_id, account_id)
      admin_account = Account.find_by(id: account_id)
      return false unless admin_account

      community_user = User.find_by(account_id: admin_account.id)
      return false unless community_user

      community_admin = NewsmastMastodon::CommunityAdmin.includes(:community).find_by(account_id: admin_account.id, is_boost_bot: true)
      return false unless community_admin

      admin_access_token = NewsmastMastodon::FetchAdminAccessTokenService.new(community_user.id).call
      return false unless admin_access_token

      community = community_admin&.community
      return false unless community

      if community&.channel_type == "newsmast"
        boost_by_newsmast_bot(community_admin, status_id)
      else
        begin
          NewsmastMastodon::ReblogRequestService.new.call(admin_access_token, status_id)
          channels = ENV.fetch("FOR_YOU_TIMELINE_CHANNELS", nil).presence&.split(/\s*,\s*/)&.reject(&:blank?)&.map(&:downcase) || []
          NewsmastMastodon::CustomBoostBotService.new(status_id, community_admin&.username).call if channels.include?(community_admin&.username.downcase)
        rescue => e
          Rails.logger.error "ReblogRequestService failed: - #{e.message}"
          false
        end
      end
    end

    private

    def boost_by_newsmast_bot(community_admin, status_id)
      @status = Status.find_by(id: status_id)
      return false unless @status

      return false if @status.nil? || @status.reply? || community_admin.nil?

      post_url = fetch_post_url
      bot_lamda_service = NewsmastMastodon::BoostLamdaNewsmastService.new
      boost_status = bot_lamda_service.boost_status(community_admin&.username, @status.id, post_url.to_s)
      return true if boost_status["statusCode"] == 200

      false
    end

    def fetch_post_url
      username = @status.account.pretty_acct
      "https://channel.org/@#{username}/#{@status.id}"
    end
  end
end
