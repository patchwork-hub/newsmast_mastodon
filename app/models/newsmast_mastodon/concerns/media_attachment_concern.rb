# frozen_string_literal: true

module NewsmastMastodon
  module Concerns
    module MediaAttachmentConcern
      extend ActiveSupport::Concern

      included do
        belongs_to :patchwork_drafted_status,
                   inverse_of: :media_attachments,
                   optional: true,
                   class_name: "NewsmastMastodon::DraftedStatus"

        scope :attached,   -> { where.not(status_id: nil).or(where.not(scheduled_status_id: nil)).or(where.not(patchwork_drafted_status_id: nil)) }
        scope :unattached, -> { where(status_id: nil, scheduled_status_id: nil, patchwork_drafted_status_id: nil) }

        IMAGE_ALLOW_TYPES = %w[image/jpeg image/jpg image/png image/gif image/webp image/bmp].freeze

        after_save :call_generate_alt_text_worker,
                   if: -> { ENV["ALT_TEXT_ENABLED"].present? && ENV["ALT_TEXT_ENABLED"].to_s.downcase == "true" }

        def can_generate_alt?
          skip_user_setting = ENV["SKIP_ALT_TEXT_USER_SETTING"].present? && ENV["SKIP_ALT_TEXT_USER_SETTING"].to_s.downcase == "true"
          user_check_passes = true

          unless skip_user_setting
            user_toggle_required = ENV["ALT_TEXT_USER_TOGGLE"].present? && ENV["ALT_TEXT_USER_TOGGLE"].to_s.downcase == "true"
            user_check_passes    = user_toggle_required ? check_alt_text_enabled? : true
          end

          is_valid_content_type? && check_user_desc? && local_or_reblogged_status? && user_check_passes
        end

        def check_alt_text_enabled?
          user = User.find_by_account_id(account_id)
          user&.alttext_enabled
        end

        def check_user_desc?
          !description.present?
        end

        def is_valid_content_type?
          IMAGE_ALLOW_TYPES.include?(file_content_type)
        end

        def local_or_reblogged_status?
          return true if remote_url.blank?

          if status_id.present?
            status = self.status
            return true if status.local? || status.reply?

            status.reblog? && status.account.domain.nil?
          else
            false
          end
        end
      end

      private

      def call_generate_alt_text_worker
        return unless can_generate_alt?

        NewsmastMastodon::GenerateAltTextWorker.perform_async(id)
      end
    end
  end
end
