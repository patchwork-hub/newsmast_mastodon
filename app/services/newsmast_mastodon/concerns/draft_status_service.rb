# frozen_string_literal: true

module NewsmastMastodon
  module Concerns
    # Adds draft support to PostStatusService (`options[:drafted]`).
    #
    # Implemented as small `super`-calling hooks rather than a copy of
    # `PostStatusService#call`, so upstream behaviour in `#call` (idempotency
    # lock, IdempotencyError handling, Antispam handling, ordering) is always
    # inherited from the host Mastodon version.
    #
    # Upstream flow (Mastodon 4.6.10):
    #   preprocess_attributes!
    #   with_idempotency { validate_media!; scheduled? ? schedule_status! : process_status! }
    #   postprocess_status! + bump_potential_friendship! unless scheduled?
    #
    # A draft takes the `process_status!` branch (scheduling wins if both are
    # given), is persisted as a NewsmastMastodon::DraftedStatus, and skips all
    # post-processing (no distribution, notifications, trends, etc.).
    module DraftStatusService
      extend ActiveSupport::Concern

      private

      def preprocess_attributes!
        super
        @drafted = @options[:drafted]
      end

      def drafted?
        @drafted.present?
      end

      def process_status!
        return draft_status! if drafted?

        super
      end

      def postprocess_status!
        return if drafted?

        super
      end

      def bump_potential_friendship!
        return if drafted?

        super
      end

      def idempotency_duplicate
        return super unless drafted?

        @account.patchwork_drafted_statuses.find(@idempotency_duplicate)
      end

      def draft_status!
        status_for_validation = @account.statuses.build(status_attributes)
        safeguard_private_mention_quote!(status_for_validation)

        antispam = Antispam.new(status_for_validation)
        antispam.local_preflight_check!

        raise ActiveRecord::RecordInvalid unless status_for_validation.valid?

        # Marking the status as destroyed is necessary to prevent the status from being
        # persisted when the associated media attachments get updated when creating the
        # drafted status.
        status_for_validation.destroy

        # The following transaction block is needed to wrap the UPDATEs to
        # the media attachments when the drafted status is created
        ApplicationRecord.transaction do
          @status = @account.patchwork_drafted_statuses.create!(drafted_status_attributes)
        end
      rescue Antispam::SilentlyDrop
        # Mirrors upstream `schedule_status!`: return an unsaved record so the
        # client sees success while nothing is persisted.
        @status = @account.patchwork_drafted_statuses.new(drafted_status_attributes).tap(&:delete)
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
