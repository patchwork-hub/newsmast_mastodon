# frozen_string_literal: true

#   custom_feeds/.../status_concern.rb    (mix channel timeline callbacks)
#   posts/.../status_concern.rb           (fetch_reblogs, without_original_statuses, without_direct_statuses, boost_posts)
module NewsmastMastodon
  module Concerns
    module StatusConcern
      extend ActiveSupport::Concern

      included do
        # --- Scopes ---
        scope :domain_filter_by_server_setting_scope, ->(account) {
          where.not(account_id: account.excluded_domain_by_server_setting_federation)
        }

        scope :without_banned,             -> { where(statuses: { is_banned: false }) }
        # Override Status::SearchConcern scope
        scope :indexable,                  -> { without_reblogs.without_banned.public_visibility.joins(:account).where(account: { indexable: true }) }

        scope :without_local_only,         -> { where(local_only: [ false, nil ]) }

        scope :fetch_reblogs,              -> { where.not(statuses: { reblog_of_id: nil }) }
        scope :without_original_statuses,  -> { where.not(reply: false) }
        scope :without_direct_statuses,    -> { where.not(visibility: Status.visibilities[:direct]) }

        scope :tagged_without, ->(tag_ids) {
          return all if tag_ids.blank?

          where.not(id: Status.joins(:statuses_tags).where(statuses_tags: { tag_id: tag_ids }).select(:id))
        }

        # --- Callbacks ---
        before_create :set_locality

        after_create_commit :filter_banned_keywords

        after_create :add_status_to_mix_channel_local_timeline, if: :for_you_timeline_enabled?
        after_destroy :remove_status_from_mix_channel_local_timeline, if: :for_you_timeline_enabled?

        after_create :boost_posts, if: :boost_posts_enabled?

        # --- Instance methods ---
        def local_only?
          local_only
        end

        def mentioned_account?(account_id)
          mentions.any? { |mention| mention.account_id == account_id }
        end
      end

      def search_word_in_status(keyword)
        sanitized_text = text.gsub(/<br\s*\/?>/, " ").gsub(/<\/?p>/, " ")
        sanitized_text = ActionView::Base.full_sanitizer.sanitize(sanitized_text)
        regex = /(?:^|\s)#{Regexp.escape(keyword)}(?:\s|[#,.]|(?=\z))/i
        !!(sanitized_text =~ regex)
      end

      private

      def set_locality
        self.local_only = reblog.local_only if reblog?
      end

      def filter_banned_keywords
        # Local statuses are enqueued from Mastodon's PostStatusService after post-processing.
        return if local?

        NewsmastMastodon::BanStatusWorker.perform_async(id)
      end

      def for_you_timeline_enabled?
        ActiveModel::Type::Boolean.new.cast(ENV["FOR_YOU_TIMELINE_ENABLED"])
      end

      def add_status_to_mix_channel_local_timeline
        if local? && public_visibility?
          NewsmastMastodon::CustomTimelineService.new.add_custom_public_status(id)
        end
      end

      def remove_status_from_mix_channel_local_timeline
        if local? && public_visibility?
          NewsmastMastodon::CustomTimelineService.new.remove_custom_public_status(id)
        end
      end

      def boost_posts_enabled?
        ENV["BOOST_POST_ENABLED"].present? && ENV["BOOST_POST_ENABLED"].to_s.downcase == "true"
      end

      def boost_posts
        return unless local? && !reblog? && !reply?
        return unless ENV.values_at("BOOST_POST_INSTANCE_URL", "BOOST_POST_USERNAME", "BOOST_POST_USER_DOMAIN").all?(&:present?)

        post_url = ActivityPub::TagManager.instance.url_for(self)
        return unless post_url

        NewsmastMastodon::BoostPostWorker.perform_async(post_url)
      end
    end
  end
end
