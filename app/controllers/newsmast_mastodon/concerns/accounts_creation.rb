# frozen_string_literal: true

module NewsmastMastodon::Concerns::AccountsCreation
  extend ActiveSupport::Concern
  include NonChannelHelper
  include PatchworkHelper
  include MoMeHelper

  def create
    membership_result = NewsmastMastodon::CivicrmMembershipCheckService.new(account_params[:email]).call
    return render_membership_error(membership_result.error_message) unless membership_result.valid?

    params_with_reason = account_params.merge(reason: "Signing up via #{ ENV.fetch('LOCAL_DOMAIN', nil) } App")
    fields_attributes = membership_fields_attributes(membership_result.user_groups)
    params_with_reason[:fields_attributes] = fields_attributes if fields_attributes.present?
    token    = AppSignUpService.new.call(doorkeeper_token.application, request.remote_ip, params_with_reason)
    response = Doorkeeper::OAuth::TokenResponse.new(token)

    headers.merge!(response.headers)

    self.response_body = response.body.to_json
    self.status        = response.status
    create_community_admin unless is_non_channel?
    generate_opt_token
  rescue ActiveRecord::RecordInvalid => e
    render json: ValidationErrorFormatter.new(e, 'account.username': :username, 'invite_request.text': :reason).as_json,
           status: 422
  end

  private

  def render_membership_error(message)
    invalid_user = User.new
    invalid_user.errors.add(:email, message)
    exception = ActiveRecord::RecordInvalid.new(invalid_user)

    render json: ValidationErrorFormatter.new(exception, 'user.email': :email).as_json,
           status: 422
  end

  def generate_opt_token
    user = User.find_by(email: account_params[:email])
    return unless user && defined?(CustomPasswordsMailer)

    user.otp_secret = SecureRandom.random_number(10_000).to_s.rjust(4, "0")
    user.save!
    CustomPasswordsMailer.with(user: user).reset_password_confirmation.deliver_later
  end

  def membership_fields_attributes(user_groups)
    filtered_groups = Array(user_groups)
      .map { |group| group.to_s.strip }
      .reject(&:blank?)
      .reject { |group| group.casecmp?("Newsletter sign-up") }
      .first(4)

    filtered_groups.each_with_index.to_h do |group, index|
      [ index.to_s, { name: "CSID Badge", value: group } ]
    end
  end

  def create_community_admin
    return unless patchwork_community_admin_exist?

    community_admin = NewsmastMastodon::CommunityAdmin.new(
      email: account_params[:email],
      username: account_params[:username],
      password: account_params[:password]
    )
    community_admin.save
  end

  def account_params
    params.permit(:username, :email, :password, :agreement, :locale, :reason, :time_zone, :invite_code, :date_of_birth).merge(invitation_code: params[:invitation_code], skip_waitlist: params[:skip_waitlist])
  end
end
