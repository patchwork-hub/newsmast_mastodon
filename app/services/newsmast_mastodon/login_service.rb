# frozen_string_literal: true


module NewsmastMastodon
  class LoginService
    include PatchworkHelper

    def initialize(params)
      @params = params
      @user = fetch_user_credentials
    end

    def channel_login
      error_message = if ENV.fetch("MAIN_CHANNEL", nil) != nil && ENV.fetch("MAIN_CHANNEL", nil) != "false"
        web_login? ? handle_web_login : handle_app_login
      end
    end

    def non_channel_login
      nil
    end

    def bristol_cable_login
      NewsmastMastodon::BristolcableLoginService.new(@params).login if ENV.fetch("LOCAL_DOMAIN", nil) == "thebristolcable.social"
    end

    def two_factor_enabled?
      @user&.two_factor_enabled?
    end

    private

    def fetch_user_credentials
      ::User.find_by(email: @params[:username])
    end

    def fetch_channel_credentials(user)
      return unless patchwork_community_admin_exist?

      NewsmastMastodon::CommunityAdmin.joins(:community).find_by(
        account_id: user.account_id,
        is_boost_bot: true,
        account_status: NewsmastMastodon::CommunityAdmin.account_statuses["active"],
        community: { deleted_at: nil }
      )
    end

    def channel_active?(user)
      return false unless patchwork_community_admin_exist?

      community_admin = NewsmastMastodon::CommunityAdmin.find_by(account_id: user.account_id, is_boost_bot: true)
      return true if community_admin.nil? || community_admin&.account_status == NewsmastMastodon::CommunityAdmin.account_statuses["active"]

      return true if community_admin&.community&.deleted_at.nil?

      false
    end

    def handle_web_login
      return nil if client_credentials?

      user = fetch_user_credentials
      return I18n.t("login_service.errors.unauthorized_access") if user.nil? || user&.confirmed_at.nil?

      return I18n.t("login_service.errors.invalid_role_access", role: user.role&.name&.underscore&.humanize) unless user.role&.name.eql?("UserAdmin") || user.role&.name.eql?("HubAdmin") || user.role&.name.eql?("MasterAdmin")

      return I18n.t("login_service.errors.deactivated_channel") unless channel_active?(user)

      nil
    end

    def handle_app_login
      return nil if client_credentials?

      user = grant_password? ? fetch_user_credentials : fetch_access_token_grant
      return I18n.t("login_service.errors.unauthorized_access") if user.nil?

      community_admin = fetch_channel_credentials(user)
      return I18n.t("login_service.errors.channel_not_created") if community_admin.nil?

      return I18n.t("login_service.errors.account_deleted") if community_admin&.account_status == "deleted"

      return I18n.t("login_service.errors.invalid_credentials") unless valid_permissions?(community_admin, user)

      nil
    end

    # This is a solution to allow the creation of a Channel feed and Hub
    def web_login?
      truthy_param?(@params[:is_web_login])
    end

    def valid_permissions?(community_admin, user)
      belong_any_channel?(community_admin) &&
        (
          (community_admin&.role.eql?("OrganisationAdmin") && user.role&.name.eql?("OrganisationAdmin")) ||
          (community_admin&.role.eql?("UserAdmin") && user.role&.name.eql?("UserAdmin")) ||
          (community_admin&.role.eql?("HubAdmin") && user.role&.name.eql?("HubAdmin"))
        )
    end

    def belong_any_channel?(community_admin)
      return false unless patchwork_community_exist?

      return false if community_admin&.patchwork_community_id.blank?

      NewsmastMastodon::Community.exists?(
        id: community_admin.patchwork_community_id,
        visibility: NewsmastMastodon::Community.visibilities.keys
      )
    end

    def render_error(error)
      render json: { error: error }, status: 401
    end

    def grant_password?
      @params[:grant_type] == "password"
    end

    def client_credentials?
      @params[:grant_type] == "client_credentials"
    end

    def authorization_code?
      @params[:grant_type] == "authorization_code"
    end

    def fetch_access_token_grant
      access_token_grant = Doorkeeper::AccessGrant.find_by(token: @params[:code])
      ::User.find_by(id: access_token_grant&.resource_owner_id)
    end

    def truthy_param?(key)
      ActiveModel::Type::Boolean.new.cast(key)
    end
  end
end
