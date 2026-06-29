# frozen_string_literal: true

# Home timeline wrapper that forwards supported filter params to FeedConcern#get.
# Callers may use either :exclude_direct_statuses or :exclude_directs.
module NewsmastMastodon
  module Overrides
    module HomeExtendedTimeline
      include TimelinePatchworkPostReactions

      DEFAULT_STATUSES_LIMIT = 20

      def show
        with_read_replica do
          @statuses = load_statuses
          @relationships = StatusRelationshipsPresenter.new(@statuses, current_user&.account_id)
          @patchwork_post_reactions = build_patchwork_post_reactions(@statuses)
        end

        add_async_refresh_header(account_home_feed.async_refresh, retry_seconds: 5)

        render json: @statuses,
               each_serializer: REST::StatusSerializer,
               relationships: @relationships,
               include_patchwork_post_reactions: true,
               patchwork_post_reactions: @patchwork_post_reactions,
               status: account_home_feed.regenerating? ? 206 : 200
      end

      def home_statuses
        account_home_feed.get(
          limit_param(DEFAULT_STATUSES_LIMIT),
          params[:max_id],
          params[:since_id],
          params[:min_id],
          current_account,
          truthy_param?(:exclude_direct_statuses) || truthy_param?(:exclude_directs),
          truthy_param?(:exclude_followed_tags),
          truthy_param?(:exclude_replies),
          truthy_param?(:grouped_admin_statuses)
        )
      end
    end
  end
end
