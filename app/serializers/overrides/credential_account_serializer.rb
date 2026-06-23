# frozen_string_literal: true

module Overrides::CredentialAccountSerializer
  def source
    user = object&.user

    {
      privacy: user&.setting_default_privacy,
      sensitive: user&.setting_default_sensitive,
      language: user&.setting_default_language,
      note: object.note,
      fields: object.fields.map(&:to_h),
      follow_requests_count: FollowRequest.where(target_account: object).limit(40).count,
      hide_collections: object.hide_collections,
      discoverable: object.discoverable,
      indexable: object.indexable,
      email: user&.email,
      attribution_domains: object.attribution_domains
    }
  end
end
