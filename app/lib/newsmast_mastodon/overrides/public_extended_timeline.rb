# frozen_string_literal: true

module NewsmastMastodon
  module Overrides
    module PublicExtendedTimeline
      include TimelinePatchworkPostReactions

      PERMITTED_PARAMS = %i[local remote limit only_media with_reblogs with_replies grouped_admin_statuses].freeze

      def show
        cache_if_unauthenticated!
        @statuses = load_statuses
        @patchwork_post_reactions = build_patchwork_post_reactions(@statuses)

        render json: @statuses,
               each_serializer: REST::StatusSerializer,
               relationships: StatusRelationshipsPresenter.new(@statuses, current_user&.account_id),
               include_patchwork_post_reactions: true,
               patchwork_post_reactions: @patchwork_post_reactions
      end

      def public_feed
        PublicFeed.new(
          current_account,
          local: truthy_param?(:local),
          remote: truthy_param?(:remote),
          only_media: truthy_param?(:only_media),
          with_reblogs: truthy_param?(:with_reblogs),
          with_replies: truthy_param?(:with_replies),
          grouped_admin_statuses: truthy_param?(:grouped_admin_statuses)
        )
      end
    end
  end
end
