module NewsmastMastodon::Api::V1::StatusesControllerExtension
  def create
    @status = PostStatusService.new.call(
      current_user.account,
      text: status_params[:status],
      thread: @thread,
      quoted_status: @quoted_status,
      quote_approval_policy: quote_approval_policy,
      media_ids: status_params[:media_ids],
      sensitive: status_params[:sensitive],
      spoiler_text: status_params[:spoiler_text],
      visibility: status_params[:visibility],
      language: status_params[:language],
      scheduled_at: status_params[:scheduled_at],
      application: doorkeeper_token.application,
      poll: status_params[:poll],
      allowed_mentions: status_params[:allowed_mentions],
      idempotency: request.headers["Idempotency-Key"],
      with_rate_limit: true,
      local_only: status_params[:local_only]
    )

    render json: @status, serializer: serializer_for_status
  rescue PostStatusService::UnexpectedMentionsError => e
    render json: unexpected_accounts_error_json(e), status: 422
  end

  private

  def status_params
    params.permit(
      :status,
      :in_reply_to_id,
      :quoted_status_id,
      :quote_approval_policy,
      :sensitive,
      :spoiler_text,
      :visibility,
      :language,
      :local_only,
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
end
