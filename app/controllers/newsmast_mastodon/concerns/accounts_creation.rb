# frozen_string_literal: true

module NewsmastMastodon::Concerns::AccountsCreation
  extend ActiveSupport::Concern

  def create
    params_with_reason = account_params
    params_with_reason[:reason] = signup_reason(params_with_reason[:reason])
    token    = AppSignUpService.new.call(doorkeeper_token.application, request.remote_ip, params_with_reason)
    response = Doorkeeper::OAuth::TokenResponse.new(token)

    headers.merge!(response.headers)

    self.response_body = response.body.to_json
    self.status        = response.status
    generate_opt_token
  rescue ActiveRecord::RecordInvalid => e
    render json: ValidationErrorFormatter.new(e, 'account.username': :username, 'invite_request.text': :reason).as_json,
           status: 422
  end

  private

  def signup_reason(reason)
    reason.presence || "Signing up via #{ ENV.fetch('LOCAL_DOMAIN', nil) } App"
  end

  def generate_opt_token
    user = User.find_by(email: account_params[:email])
    return unless user && defined?(CustomPasswordsMailer)

    user.otp_secret = SecureRandom.random_number(10_000).to_s.rjust(4, "0")
    user.save!
    CustomPasswordsMailer.with(user: user).reset_password_confirmation.deliver_later
  end

  def account_params
    params.permit(:username, :email, :password, :agreement, :locale, :reason, :time_zone, :invite_code, :date_of_birth)
  end
end
