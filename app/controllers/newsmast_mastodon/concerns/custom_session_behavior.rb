# frozen_string_literal: true

module NewsmastMastodon::Concerns::CustomSessionBehavior
  extend ActiveSupport::Concern
  include NonChannelHelper

  def create
    self.resource = warden.authenticate!(auth_options)

    unless is_non_channel?
      if login_blocked_for?(resource) # rubocop:disable Style/SoleNestedConditional
        handle_invalid_user_login(resource)
        return
      end
    end

    super do |resource|
      # We only need to call this if this hasn't already been
      # called from one of the two-factor or sign-in token
      # authentication methods

      on_authentication_success(resource, :password) unless @on_authentication_success_called
    end
  end

  private

  def login_blocked_for?(user)
    invalid_admin_login?(user)
  end

  def invalid_admin_login?(user)
    return false unless has_special_role?(user, %w[UserAdmin HubAdmin OrganisationAdmin NewsmastAdmin])

    !has_valid_community_admin?(user, roles: %w[UserAdmin HubAdmin OrganisationAdmin NewsmastAdmin], boost_bot: true)
  end

  def has_special_role?(user, role_names)
    return false unless user.present? && user.role.present?

    user.role.id == -99 || user.role.id.nil? || role_names.include?(user.role.name)
  end

  def has_valid_community_admin?(user, roles:, boost_bot:)
    return false unless user.account_id.present?

    return false unless Object.const_defined?("NewsmastMastodon::CommunityAdmin") || Object.const_defined?("NewsmastMastodon::Community")

    return false unless defined?(NewsmastMastodon::CommunityAdmin) && NewsmastMastodon::CommunityAdmin.respond_to?(:find_by)

    return false unless defined?(NewsmastMastodon::Community) && NewsmastMastodon::Community.respond_to?(:find_by)

    NewsmastMastodon::Community.joins(:community_admins)
             .where(community_admins: {
               account_id: user.account_id,
               role: roles,
               is_boost_bot: boost_bot,
               account_status: NewsmastMastodon::CommunityAdmin.account_statuses["active"]
             })
             .exists?
  end

  def handle_invalid_user_login(user)
    sign_out(user)
    flash[:error] = I18n.t("migrations.errors.not_found")
    redirect_to new_user_session_path
  end
end
