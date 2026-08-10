# frozen_string_literal: true


module NewsmastMastodon
  module Overrides
    module PostStatusServiceExtension
      private

      def postprocess_status!
        process_hashtags_service.call(@status)
        Trends.tags.register(@status)
        LinkCrawlWorker.perform_async(@status.id)
        DistributionWorker.perform_async(@status.id)
        process_email_subscriptions!

        ActivityPub::DistributionWorker.perform_async(@status.id) unless @status.local_only?
        PollExpirationNotifyWorker.perform_at(@status.poll.expires_at, @status.poll.id) if @status.poll
        ActivityPub::QuoteRequestWorker.perform_async(@status.quote.id) if @status.quote&.quoted_status.present? && !@status.quote&.quoted_status&.local?

        # Trigger content filter checks for status banning, regardless of local-only status.
        NewsmastMastodon::BanStatusWorker.perform_async(@status.id) if @status&.id.present?
      end

      def local_only_option(local_only, in_reply_to)
        if local_only.nil?
          return true if in_reply_to&.local_only
          return false if in_reply_to && !in_reply_to.local_only
        end
        local_only
      end

      def status_attributes
        {
          text: @text,
          media_attachments: @media || [],
          ordered_media_attachment_ids: (@options[:media_ids] || []).map(&:to_i) & @media.map(&:id),
          thread: @in_reply_to,
          poll_attributes: poll_attributes,
          sensitive: @sensitive,
          spoiler_text: @options[:spoiler_text] || "",
          visibility: @visibility,
          language: valid_locale_cascade(@options[:language], @account.user&.preferred_posting_language, I18n.default_locale),
          application: @options[:application],
          rate_limit: @options[:with_rate_limit],
          quote_approval_policy: @options[:quote_approval_policy],
          local_only: local_only_option(@options[:local_only], @in_reply_to)
        }.compact
      end
    end
  end
end
