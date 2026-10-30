# frozen_string_literal: true

# GEM_SPLIT[AUTH-04]: DISABLED at cutover (2026-10-30) — no longer prepended
# into Api::V1::AccountsController (see config/initializers/prepend_concerns.rb);
# PatchworkExtensions::Concerns::AccountsCreation serves the create flow while
# both gems are loaded. Retained until the verification window closes; then
# remove this file and spec/controllers/newsmast_mastodon/concerns/accounts_creation_spec.rb.
module NewsmastMastodon::Concerns::AccountsCreation
  extend ActiveSupport::Concern
  include NonChannelHelper
  include PatchworkHelper
  include MoMeHelper

  def create
    membership_result = NewsmastMastodon::CivicrmMembershipCheckService.new(account_params[:email]).call
    return render_membership_error(membership_result.error_message) unless membership_result.valid?

    params_with_reason = account_params
    params_with_reason[:reason] = signup_reason(params_with_reason[:reason])
    token    = AppSignUpService.new.call(doorkeeper_token.application, request.remote_ip, params_with_reason)
    response = Doorkeeper::OAuth::TokenResponse.new(token)

    headers.merge!(response.headers)

    self.response_body = response.body.to_json
    self.status        = response.status
    create_community_admin unless is_non_channel?
    generate_opt_token
    enqueue_role_assignment(token)
  rescue ActiveRecord::RecordInvalid => e
    render json: ValidationErrorFormatter.new(e, 'account.username': :username, 'invite_request.text': :reason).as_json,
           status: 422
  end

  private

  def signup_reason(reason)
    reason.presence || "Signing up via #{ ENV.fetch('LOCAL_DOMAIN', nil) } App"
  end

  def enqueue_role_assignment(token)
    enabled = ActiveModel::Type::Boolean.new.cast(ENV.fetch("CSID_ROLE_ASSIGNMENT_ENABLED", "false"))
    return unless enabled
    return if token.resource_owner_id.blank?

    NewsmastMastodon::CivicrmRoleAssignmentWorker.perform_async(token.resource_owner_id)
  rescue StandardError => e
    Rails.logger.error("CiviCRM role assignment enqueue failed: #{e.class}")
  end

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
