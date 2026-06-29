require "httparty"
require "jwt"

module NewsmastMastodon::Api::V1::Accounts
  class GhostSubscriptionsController < ::Api::BaseController
    include ::NewsmastMastodon::Concerns::ApiResponseHelper
    before_action -> { doorkeeper_authorize! :read, :write }
    before_action :require_user!

    # manage email subscription to Ghost Site
    def manage_subscription
      email = subscription_params[:email]
      is_subscribe = ActiveModel::Type::Boolean.new.cast(subscription_params[:subscribe])
      member = find_member_by_email(email)
      member ? update_member_subscribe(member["id"], is_subscribe) : create_ghost_member(email, is_subscribe)
    rescue => e
      render_errors(e.message, :internal_server_error)
    end

    private

    def subscription_params
      params.permit(:email, :subscribe)
    end

    # email subscription update to Ghost Site
    def update_member_subscribe(member_id, is_subscribe)
      body = {
        members: [ {
          subscribed: is_subscribe
        } ]
      }.to_json
      response = HTTParty.put("#{ghost_member_url}#{member_id}/", headers: ghost_headers, body: body)
      handle_response(response, "Update successfully", :ok)
    end

    # create a member on Ghost Site
    def create_ghost_member(email, is_subscribe)
      body = {
        members: [ {
          email: email,
          subscribed: is_subscribe
        } ]
      }.to_json
      response = HTTParty.post(ghost_member_url, headers: ghost_headers, body: body)
      handle_response(response, "New member subscribed", :created)
    end

    # find email subscription member to Ghost Site
    def find_member_by_email(email)
      # Ghost filter syntax: email:'user@example.com'
      query_url = "#{ghost_member_url}?filter=email:#{email}"
      response = HTTParty.get(query_url, headers: ghost_headers)

      if response.success?
        response.parsed_response["members"]&.first
      else
        nil
      end
    end

    def ghost_member_url
      url = ENV["GHOST_URL"]
      if url.blank?
        raise "Configuration Error: GHOST_URL environment variable is missing"
      end
      "#{url}/ghost/api/admin/members/"
    end

    def ghost_headers
      api_key = ENV["GHOST_ADMIN_API_KEY"]
      if api_key.blank? || !api_key.include?(":")
        raise "Configuration Error: Ghost API Key is missing."
      end
      id, secret = api_key.split(":")
      header = { alg: "HS256", typ: "JWT", kid: id }
      payload = { iat: Time.now.to_i, exp: Time.now.to_i + 300, aud: "/admin/" }
      token = JWT.encode(payload, [ secret ].pack("H*"), "HS256", header)

      { "Authorization" => "Ghost #{token}", "Content-Type" => "application/json" }
    end

    def handle_response(response, success_message, success_status)
      if response.success?
        render_success({}, success_message, success_status)
      else
        render_errors(response.body, :unprocessable_entity)
      end
    end
  end
end
