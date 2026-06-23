# frozen_string_literal: true


module NewsmastMastodon
  class GenerateAltTextWorker
    include Sidekiq::Worker
    sidekiq_options queue: "default", retry: 2, dead: false, retry_in: ->(_count) { 24.hours }

    def perform(media_attachment_id)
      @media_attachment = MediaAttachment.find(media_attachment_id)
      if @media_attachment.present?
        NewsmastMastodon::AfterUploadImageService.new(@media_attachment.id).call if @media_attachment.can_generate_alt?
      end
    end
  end
end
