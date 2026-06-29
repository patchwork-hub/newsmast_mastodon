# frozen_string_literal: true

module NewsmastMastodon
  module Overrides
    module AccountStatusesControllerExtension
      include TimelinePatchworkPostReactions

      def index
        cache_if_unauthenticated!
        @statuses = load_statuses
        @patchwork_post_reactions = build_patchwork_post_reactions(@statuses)

        render json: @statuses,
               each_serializer: REST::StatusSerializer,
               relationships: StatusRelationshipsPresenter.new(@statuses, current_user&.account_id),
               include_patchwork_post_reactions: true,
               patchwork_post_reactions: @patchwork_post_reactions
      end
    end
  end
end