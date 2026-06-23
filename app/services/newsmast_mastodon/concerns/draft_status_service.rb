# frozen_string_literal: true


module NewsmastMastodon
  module Concerns
    module DraftStatusService
      extend ActiveSupport::Concern

      # Post a text status update, fetch and notify remote users mentioned
      # @param [Account] account Account from which to post
      # @param [Hash] options
      # @option [String] :text Message
      # @option [Status] :thread Optional status to reply to
      # @option [Status] :quoted_status Optional status to quote
      # @option [String] :quote_approval_policy Approval policy for quotes, one of `public`, `followers` or `nobody`
      # @option [Boolean] :sensitive
      # @option [String] :visibility
      # @option [String] :spoiler_text
      # @option [String] :language
      # @option [String] :scheduled_at
      # @option [Hash] :poll Optional poll to attach
      # @option [Enumerable] :media_ids Optional array of media IDs to attach
      # @option [Doorkeeper::Application] :application
      # @option [String] :idempotency Optional idempotency key
      # @option [Boolean] :with_rate_limit
      # @option [Enumerable] :allowed_mentions Optional array of expected mentioned account IDs, raises `UnexpectedMentionsError` if unexpected accounts end up in mentions
      # @return [Status]
      def call(account, options = {})
        @account     = account
        @options     = options
        @text        = @options[:text] || ""
        @in_reply_to = @options[:thread]
        @quoted_status = @options[:quoted_status]

        return idempotency_duplicate if idempotency_given? && idempotency_duplicate?

        validate_media!
        preprocess_attributes!

        if scheduled?
          schedule_status!
        elsif drafted?
          draft_status!
        else
          process_status!
        end

        redis.setex(idempotency_key, 3_600, @status.id) if idempotency_given?

        unless scheduled? || drafted?
          postprocess_status!
          bump_potential_friendship!
        end

        @status
      rescue => e
        if defined?(Antispam::SilentlyDrop) && e.is_a?(Antispam::SilentlyDrop)
          e.status
        else
          raise
        end
      end

      private

      def preprocess_attributes!
        @sensitive    = (@options[:sensitive].nil? ? @account.user&.setting_default_sensitive : @options[:sensitive]) || @options[:spoiler_text].present?
        @text         = @options.delete(:spoiler_text) if @text.blank? && @options[:spoiler_text].present? && @quoted_status.blank?
        @visibility   = @options[:visibility] || @account.user&.setting_default_privacy
        @visibility   = :unlisted if @visibility&.to_sym == :public && @account.silenced?
        @visibility   = :private if @quoted_status&.private_visibility? && %i[public unlisted].include?(@visibility&.to_sym)
        @scheduled_at = @options[:scheduled_at]&.to_datetime
        @scheduled_at = nil if scheduled_in_the_past?
        @drafted      = @options[:drafted]
      rescue ArgumentError
        raise ActiveRecord::RecordInvalid
      end

      def drafted?
        @drafted.present?
      end

      def draft_status!
        status_for_validation = @account.statuses.build(status_attributes)
        safeguard_private_mention_quote!(status_for_validation)

        antispam = Antispam.new(status_for_validation)
        antispam.local_preflight_check!

        if status_for_validation.valid?
          # Marking the status as destroyed is necessary to prevent the status from being
          # persisted when the associated media attachments get updated when creating the
          # scheduled status.
          status_for_validation.destroy

          # The following transaction block is needed to wrap the UPDATEs to
          # the media attachments when the scheduled status is created

          ApplicationRecord.transaction do
            @status = @account.patchwork_drafted_statuses.create!(drafted_status_attributes)
          end
        else
          raise ActiveRecord::RecordInvalid
        end
      rescue => e
        if defined?(Antispam::SilentlyDrop) && e.is_a?(Antispam::SilentlyDrop)
          @status = @account.patchwork_drafted_status.new(drafted_status_attributes).tap(&:delete)
        else
          raise
        end
      end

      def drafted_status_attributes
        {
          media_attachments: @media || [],
          params: scheduled_options
        }
      end
    end
  end
end
