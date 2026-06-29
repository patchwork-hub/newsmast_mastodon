# frozen_string_literal: true

module NewsmastMastodon::Concerns::CustomAuthenticationBehavior
  extend ActiveSupport::Concern
  include NonChannelHelper

  def create
    if client_credentials? || authorization_code?
      super
      return
    end

    if NewsmastMastodon::LoginService.new(oauth_params).two_factor_enabled?
      return render_error(I18n.t("login_service.errors.two_factor_enabled"))
    end

    error_message = if ENV.fetch("LOCAL_DOMAIN", nil) == "thebristolcable.social" || Rails.env.development?
      NewsmastMastodon::LoginService.new(oauth_params).bristol_cable_login || nil
    elsif is_non_channel?
      NewsmastMastodon::LoginService.new(oauth_params).non_channel_login || nil
    else
      NewsmastMastodon::LoginService.new(oauth_params).channel_login || nil
    end

    error_message.nil? ? super : render_error(error_message)
  end

  private

  def render_error(error)
    extracted = extract_error_message(error)
    response_body = { error: extracted[:message] }
    response_body[:data] = extracted[:data] if extracted[:data].present?

    render json: response_body, status: 401
  end

  def client_credentials?
    oauth_params[:grant_type] == "client_credentials"
  end

  def authorization_code?
    oauth_params[:grant_type] == "authorization_code"
  end

  def oauth_params
    params.permit(
      :username,
      :is_web_login,
      :grant_type,
      :code,
      :password
    )
  end

  def extract_error_message(response)
    if response.is_a?(String) && response.include?("data: ")
      # Extract the error message part (before "data:")
      message = response.split(" data: ").first.strip

      # Extract and parse the data part
      data_match = response.match(/data: (\{.*\})/)
      data = data_match ? eval(data_match[1]) : nil

      { message: message, data: data }
    else
      { message: response.to_s, data: nil }
    end
  rescue StandardError
    { message: I18n.t("login_service.errors.invalid_credentials"), data: nil }
  end
end
