# frozen_string_literal: true

module NewsmastMastodon::Concerns::UserSettingExtend
  extend ActiveSupport::Concern
  include NonChannelHelper

  def setting_default_privacy
    return false unless defined?(NewsmastMastodon::Community) && NewsmastMastodon::Community.respond_to?(:find_by)

    # Default visibility setting
    community_privacy = NewsmastMastodon::Community.default_privacy(self)
    return community_privacy if community_privacy.present?

    settings["default_privacy"] || (account.locked? ? "private" : "public")
  end
end
