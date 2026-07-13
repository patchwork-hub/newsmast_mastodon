# frozen_string_literal: true

module NewsmastMastodon::Api::V1::Channels
  class CommunityRolesController < ::Api::BaseController
    GROUP_ROLES = %w[GroupAdmin GroupModerator].freeze
    ADMIN_ROLES = %w[Owner UserAdmin HubAdmin OrganisationAdmin NewsmastAdmin].freeze
    ROLE_ASSIGNMENT_ROLES = %w[Owner UserAdmin OrganisationAdmin GroupAdmin].freeze

    before_action :require_user!
    before_action -> { doorkeeper_authorize! :read }, only: %i[search_local_accounts assigned_roles]
    before_action -> { doorkeeper_authorize! :write }, only: %i[assign_role remove_assigned_role invite_user]
    before_action :set_community
    before_action :authorize_invite_access!, only: %i[search_local_accounts assigned_roles invite_user]
    before_action :authorize_owner!, only: %i[assign_role remove_assigned_role]

    def search_local_accounts
      query = params[:query].to_s.strip
      return render json: [] if query.blank?

      accounts = Account.where(domain: nil)
                        .where("username ILIKE :q OR display_name ILIKE :q", q: "%#{query}%")
                        .limit(20)

      role_by_account_id = NewsmastMastodon::CommunityAdmin
                           .where(
                             patchwork_community_id: @community.id,
                             account_status: NewsmastMastodon::CommunityAdmin.account_statuses[:active],
                             role: GROUP_ROLES,
                             account_id: accounts.pluck(:id)
                           )
                           .pluck(:account_id, :role)
                           .to_h

      result = accounts.map do |account|
        {
          id: account.id.to_s,
          username: account.username,
          display_name: account.display_name,
          avatar_url: account_avatar_url(account),
          current_role: role_by_account_id[account.id]
        }
      end

      render json: result
    end

    def assigned_roles
      records = NewsmastMastodon::CommunityAdmin
                .includes(:account)
                .where(
                  patchwork_community_id: @community.id,
                  account_status: NewsmastMastodon::CommunityAdmin.account_statuses[:active],
                  role: GROUP_ROLES
                )

      data = records.map do |record|
        {
          account_id: record.account_id,
          role: record.role,
          username: record.account&.username || record.username,
          display_name: record.account&.display_name || record.display_name,
          avatar_url: account_avatar_url(record.account)
        }
      end

      render json: { data: data }
    end

    def assign_role
      account = Account.find_by(id: assign_role_params[:account_id])
      return render json: { success: false, error: "Account not found." }, status: :not_found unless account
      return render json: { success: false, error: "Only local accounts can be assigned." }, status: :unprocessable_entity unless account.local?

      role = assign_role_params[:role].to_s
      unless GROUP_ROLES.include?(role)
        return render json: { success: false, error: "Invalid role." }, status: :unprocessable_entity
      end

      community_admin = NewsmastMastodon::CommunityAdmin.find_or_initialize_by(
        patchwork_community_id: @community.id,
        account_id: account.id
      )

      if community_admin.new_record?
        community_admin.username = account.username
        community_admin.display_name = account.display_name
        community_admin.email = account.user&.email || "#{account.username}@localhost.local"
        community_admin.password = SecureRandom.hex(16)
      end

      community_admin.role = role
      community_admin.account_status = :active

      if community_admin.save
        render json: { success: true }
      else
        render json: { success: false, error: community_admin.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    end

    def remove_assigned_role
      account = Account.find_by(id: remove_role_params[:account_id])
      return render json: { success: false, error: "Account not found." }, status: :not_found unless account

      community_admin = NewsmastMastodon::CommunityAdmin.find_by(
        patchwork_community_id: @community.id,
        account_id: account.id,
        role: GROUP_ROLES
      )

      return render json: { success: false, error: "Admin not found." }, status: :not_found unless community_admin

      if community_admin.destroy
        render json: { success: true }
      else
        render json: { success: false, error: community_admin.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    end

    def invite_user
      wait_list = NewsmastMastodon::WaitList.new(invite_user_params)
      wait_list.channel_type = @community.hub? ? :hub : :channel
      wait_list.generate_invitation_code

      if wait_list.save
        render json: {
          success: true,
          data: {
            invitation_code: wait_list.invitation_code,
            email: wait_list.email,
            description: wait_list.description,
            channel_type: wait_list.channel_type
          }
        }, status: :created
      else
        render json: { success: false, error: wait_list.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    end

    private

    def set_community
      @community = NewsmastMastodon::Community.find_by(id: params[:id])
      return if @community

      render json: { error: "Community not found" }, status: :not_found
    end

    def authorize_owner!
      return if can_assign_roles? || active_group_role_admin_for_community?

      render json: { error: "Forbidden" }, status: :forbidden
    end

    def authorize_invite_access!
      return if owner? || admin_role? || can_manage_community_admins? || active_group_role_admin_for_community?

      render json: { error: "Forbidden" }, status: :forbidden
    end

    def owner?
      current_user&.role&.name == "Owner"
    end

    def can_assign_roles?
      ROLE_ASSIGNMENT_ROLES.include?(current_user&.role&.name)
    end

    def admin_role?
      ADMIN_ROLES.include?(current_user&.role&.name)
    end

    def can_manage_community_admins?
      role = current_user&.role
      role.respond_to?(:can?) && role.can?(:manage_community_admins)
    end

    def active_group_role_admin_for_community?
      return false unless current_user&.account_id

      NewsmastMastodon::CommunityAdmin.exists?(
        patchwork_community_id: @community.id,
        account_id: current_user.account_id,
        role: GROUP_ROLES,
        account_status: NewsmastMastodon::CommunityAdmin.account_statuses[:active]
      )
    end

    def assign_role_params
      params.permit(:account_id, :role)
    end

    def remove_role_params
      params.permit(:account_id)
    end

    def invite_user_params
      params.permit(:email, :description)
    end

    def account_avatar_url(account)
      return nil unless account

      return account.avatar_static_url if account.respond_to?(:avatar_static_url)
      return account.avatar_original_url if account.respond_to?(:avatar_original_url)
      return account.avatar.url(:original) if account.respond_to?(:avatar) && account.avatar.respond_to?(:url)

      nil
    end
  end
end
