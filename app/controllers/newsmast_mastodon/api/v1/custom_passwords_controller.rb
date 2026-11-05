# frozen_string_literal: true

module NewsmastMastodon::Api::V1
  class CustomPasswordsController < ::Api::BaseController
    include ::NewsmastMastodon::Concerns::ApiResponseHelper

    ACCESS_TOKEN_SCOPES = "read write follow push profile"
    skip_before_action :require_authenticated_user!, except: [ :change_password, :change_email ], raise: false
    before_action :require_authenticated_user!, only: [ :change_password, :change_email ]
    before_action :set_user, only: [ :update, :verify_otp, :request_otp ]

    include AccountableConcern if defined?(AccountableConcern)
    layout "email"

    def create
      user = User.find_by(email: verify_otp_params[:email])
      if user
        raw, enc = Devise.token_generator.generate(User, :reset_password_token)
        user.reset_password_token = enc
        user.reset_password_sent_at = Time.now.utc
        user.otp_secret = generate_otp_token
        user.save!
        CustomPasswordsMailer.with(user: user).reset_password_confirmation.deliver_later
        render_response(key: :reset_password_token, data: user.reload.reset_password_token, status: :ok)
      else
        render_not_found
      end
    end

    def update
      unless @user && password_params[:password].present? && password_params[:password_confirmation].present? && @user&.otp_secret.nil?
        return render_result({}, "api.account.errors.missing_field", :unprocessable_entity)
      end

      unless password_params[:password].eql?(password_params[:password_confirmation])
        return render_result({}, "api.account.errors.password_unmatch", :unprocessable_entity)
      end

      @user.password = password_params[:password]
      @user.skip_password_change_notification = true
      @user.save(validate: false)
      render_updated({}, "api.account.messages.password_updated")
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      render_result({}, "api.account.errors.password_update_fail", :unprocessable_entity)
    end

    def request_otp
      if @user
        @user.otp_secret = generate_otp_token
        @user.save!
        CustomPasswordsMailer.with(user: @user).reset_password_confirmation.deliver_later
        render_response(key: :access_token, data: verify_otp_params[:id], status: :ok)
      else
        render_not_found("api.account.errors.email_not_found")
      end
    end

    def verify_otp
      unless @user && verify_otp?(verify_otp_params[:otp_secret], reset_password: reset_password?)
        return render_result({}, "api.account.errors.otp_invalid", :unprocessable_entity)
      end

      ActiveRecord::Base.transaction do
        handle_user_confirmation()
        handle_email_change if change_email?
      end

      render_response(key: :message, data: generate_access_token, status: :ok)
    rescue ActiveRecord::RecordInvalid => e
      render_result({}, e.message, :unprocessable_entity)
    end

    def change_password
      @user = current_user

      unless @user && password_params[:password].present? &&
      password_params[:password_confirmation].present? &&
      password_params[:current_password].present? && @user&.otp_secret.nil?
        return render_result({}, "api.account.errors.missing_field", :unprocessable_entity)
      end

      unless @user.valid_password?(password_params[:current_password])
        return render_result({}, "api.account.errors.password_incorrect", :unprocessable_entity)
      end

      @user.password = password_params[:password]
      @user.skip_password_change_notification = true
      @user.save(validate: false)

      render_updated({}, "api.account.messages.password_updated")
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      render_result({}, "api.account.errors.password_update_fail", :unprocessable_entity)
    end

    def change_email
      @user = current_user
      unless @user && verify_otp_params[:email].present? && password_params[:current_password].present?
        return render_result({}, "api.account.errors.missing_field", :unprocessable_entity)
      end

      unless @user.valid_password?(password_params[:current_password])
        return render_result({}, "api.account.errors.password_incorrect", :unprocessable_entity)
      end

      new_email = verify_otp_params[:email]

      return render_result({}, "api.account.errors.email_taken", :unprocessable_entity) if User.exists?(email: new_email)

      email_regex = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
      return render_result({}, "api.account.errors.email_invalid", :unprocessable_entity) unless new_email.match?(email_regex)

      @user.skip_confirmation!
      if new_email != @user.email
        @user.update!(
          unconfirmed_email: new_email,
          confirmation_sent_at: Time.current,
          otp_secret: generate_otp_token,
          confirmed_at: nil
        )
        log_action :change_email, @user

        # Revoke all access tokens and destroy sessions
        @user.revoke_access!
        Devise.sign_out_all_scopes ? sign_out : sign_out(@user)
        CustomPasswordsMailer.with(user: @user).reset_password_confirmation.deliver_later
      end

      render_response(key: :message, data: generate_access_token, status: :ok)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      render_result({}, "api.account.errors.email_update_fail", :unprocessable_entity)
    end

    private

    def password_params
      params.permit(:password, :password_confirmation, :current_password)
    end

    def verify_otp_params
      params.permit(:id, :otp_secret, :is_reset_password, :is_change_email, :invitation_code, :email)
    end

    def set_user
      return nil if verify_otp_params[:id].nil?

      token = Doorkeeper::AccessToken.find_by(token: verify_otp_params[:id])
      @user = if token
                User.find_by(id: token.resource_owner_id)
      else
                User.find_by(reset_password_token: verify_otp_params[:id])
      end
    end

    def verify_otp?(otp_secret, reset_password: false)
      if reset_password && (@user.reset_password_sent_at.nil? || @user.reset_password_sent_at < 30.minutes.ago)
        return false
      end

      @user&.otp_secret == otp_secret
    end

    def reset_password?
      truthy_param?(verify_otp_params[:is_reset_password])
    end

    def change_email?
      truthy_param?(verify_otp_params[:is_change_email])
    end

    def generate_access_token
      access_token = Doorkeeper::AccessToken.find_or_create_by(
        resource_owner_id: @user.id,
        application_id: Doorkeeper::Application.first.id,
        revoked_at: nil
      ) do |token|
        token.scopes = ACCESS_TOKEN_SCOPES
      end

      { access_token: access_token.token,
        token_type: "Bearer",
        scope: ACCESS_TOKEN_SCOPES,
        created_at: access_token.created_at.to_i }
    end

    def generate_otp_token
      SecureRandom.random_number(10_000).to_s.rjust(4, "0")
    end

    def truthy_param?(key)
      ActiveModel::Type::Boolean.new.cast(key)
    end

    def handle_user_confirmation
      # This stage is known as the user was just registered
      # If confirmation_sent_at is present, that account wasn't confirmed yet!
      if @user.confirmation_sent_at.present?
        @user.account.update!(discoverable: false)
        @user.skip_confirmation!
        @user.prepare_new_user!
        @user.update!(otp_secret: nil, confirmed_at: Time.current, confirmation_sent_at: nil, confirmation_token: nil, approved: true)
      else
        @user.update!(otp_secret: nil)
      end
    end

    def handle_email_change
      new_email = @user.unconfirmed_email
      @user.email = new_email
      @user.skip_reconfirmation!
      @user.unconfirmed_email = nil
      @user.confirmation_token = nil
      @user.confirmed_at = Time.current
      @user.approved =  true
      @user.confirmation_sent_at = nil
      @user.save!
    end
  end
end
