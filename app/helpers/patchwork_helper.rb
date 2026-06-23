# frozen_string_literal: true

#
# NewsmastMastodon::CommunityAdmin, so there is now a single unified helper.
module PatchworkHelper
  extend ActiveSupport::Concern

  def patchwork_table_exists?(table_name)
    ActiveRecord::Base.connection.data_source_exists?(table_name)
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, PG::ConnectionBad
    false
  end

  def patchwork_server_settings_exist?
    return false unless patchwork_table_exists?("server_settings")

    return false unless Object.const_defined?("NewsmastMastodon::ServerSetting") &&
                        defined?(NewsmastMastodon::ServerSetting) &&
                        NewsmastMastodon::ServerSetting.respond_to?(:find_by)

    true
  end

  def patchwork_community_admin_exist?
    return false unless patchwork_table_exists?("patchwork_communities_admins")

    return false unless Object.const_defined?("NewsmastMastodon::CommunityAdmin") &&
                        defined?(NewsmastMastodon::CommunityAdmin) &&
                        NewsmastMastodon::CommunityAdmin.respond_to?(:find_by)

    true
  end
end
