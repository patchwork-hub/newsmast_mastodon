# frozen_string_literal: true

module NewsmastMastodon
  module Overrides
    module ScheduledStatusesController
      def update
        ActiveRecord::Base.transaction do
          @status.destroy!
          @status = post_status_service
        end

        render json: @status, serializer: REST::ScheduledStatusSerializer
      rescue PostStatusService::UnexpectedMentionsError => e
        render json: unexpected_accounts_error_json(e), status: 422
      end

      private

      def scheduled_status_params
        params.permit(
          :status,
          :in_reply_to_id,
          :sensitive,
          :spoiler_text,
          :visibility,
          :language,
          :scheduled_at,
          allowed_mentions: [],
          media_ids: [],
          media_attributes: [
            :id,
            :thumbnail,
            :description,
            :focus
          ],
          poll: [
            :multiple,
            :hide_totals,
            :expires_in,
            options: []
          ]
        )
      end

      def post_status_service
        PostStatusService.new.call(
          current_user.account,
          text: scheduled_status_params[:status],
          thread: nil,
          media_ids: scheduled_status_params[:media_ids],
          sensitive: scheduled_status_params[:sensitive],
          spoiler_text: scheduled_status_params[:spoiler_text],
          visibility: scheduled_status_params[:visibility],
          language: scheduled_status_params[:language],
          scheduled_at: scheduled_status_params[:scheduled_at],
          drafted: false,
          application: doorkeeper_token.application,
          poll: scheduled_status_params[:poll],
          allowed_mentions: scheduled_status_params[:allowed_mentions],
          idempotency: request.headers["Idempotency-Key"],
          with_rate_limit: true
        )
      end
    end
  end
end
