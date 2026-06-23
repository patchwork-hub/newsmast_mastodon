# frozen_string_literal: true


module NewsmastMastodon
  class BoostLamdaNewsmastService
    require "httparty"

    def initialize
      @base_url = ENV.fetch("BOOST_COMMUNITY_BOT_URL", nil)
      @api_key = ENV.fetch("BOOST_COMMUNITY_BOT_API_KEY", nil)
    end

    def boost_status(post_bot_account, post_id, post_url)
      HTTParty.post(@base_url,
                    body: {
                      body: {
                        post_bot: post_bot_account,
                        post_id: post_id,
                        post_url: post_url.gsub(/\s+/, "")
                      }
                    }.to_json,
                    headers: { "Content-Type" => "application/json",
                               "x-api-key" => @api_key })
    end
  end
end
