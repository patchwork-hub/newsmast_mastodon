# frozen_string_literal: true

module NewsmastMastodon
  class Community < ApplicationRecord
    self.table_name = "patchwork_communities"

    IMAGE_MIME_TYPES = [ "image/svg+xml", "image/png", "image/jpeg", "image/jpg", "image/webp" ].freeze
    LIMIT = 2.megabytes

    has_attached_file :logo_image
    has_attached_file :avatar_image
    has_attached_file :banner_image

    has_many :community_admins,
             foreign_key: "patchwork_community_id",
             dependent: :destroy,
             class_name: "NewsmastMastodon::CommunityAdmin"

    has_one :community_post_type,
            foreign_key: "patchwork_community_id",
            dependent: :destroy,
            class_name: "NewsmastMastodon::CommunityPostType"

    has_many :community_hashtags,
             class_name: "NewsmastMastodon::CommunityHashtag",
             foreign_key: "patchwork_community_id",
             dependent: :destroy

    has_one :content_type,
            class_name: "NewsmastMastodon::ContentType",
            foreign_key: "patchwork_community_id",
            dependent: :destroy

    validates :name, presence: true, uniqueness: true

    enum :visibility, public_access: 0, guest_access: 1, private_local: 2
    enum :post_visibility, { public_visibility: 0, unlisted: 1, followers_only: 2, direct: 3 }
    enum :channel_type, { channel: "channel", channel_feed: "channel_feed", hub: "hub", newsmast: "newsmast" }

    validates_attachment :logo_image,
                         content_type: { content_type: IMAGE_MIME_TYPES },
                         size: { less_than: LIMIT }

    validates_attachment :avatar_image,
                         content_type: { content_type: IMAGE_MIME_TYPES },
                         size: { less_than: LIMIT }

    validates_attachment :banner_image,
                         content_type: { content_type: IMAGE_MIME_TYPES },
                         size: { less_than: LIMIT }

    def self.default_privacy(user)
      return nil unless Object.const_defined?("NewsmastMastodon::CommunityAdmin")
      return nil unless defined?(NewsmastMastodon::CommunityAdmin) && NewsmastMastodon::CommunityAdmin.respond_to?(:find_by)

      admin = NewsmastMastodon::CommunityAdmin.find_by(
        account_id: user.account_id,
        is_boost_bot: true,
        account_status: NewsmastMastodon::CommunityAdmin.account_statuses["active"]
      )
      return nil unless admin

      community = NewsmastMastodon::Community.find_by(id: admin.patchwork_community_id)
      return nil unless community&.content_type&.group_channel?

      case community.post_visibility
      when "followers_only"
        "private"
      when "public_visibility"
        "public"
      else
        community.post_visibility
      end
    end
  end
end
