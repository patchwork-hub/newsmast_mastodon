module NewsmastMastodon::Api::V1::StatusesControllerExtension
  include NewsmastMastodon::Overrides::TimelinePatchworkPostReactions

  def show
    super
    decorate_single_status_response!
  end

  def context
    super
    decorate_context_response!
  end

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

  def decorate_single_status_response!
    payload = json_payload_hash(response.body)
    return if payload.blank?

    status_id = payload["id"]&.to_i
    return if status_id.nil?

    reactions_map = build_patchwork_post_reactions(Status.where(id: status_id).select(:id).to_a)
    payload["patchwork_post_reactions"] = reactions_map[status_id] || []
    self.response_body = JSON.generate(payload)
  end

  def decorate_context_response!
    payload = json_payload_hash(response.body)
    return if payload.blank?

    statuses = Array(payload["ancestors"]) + Array(payload["descendants"])
    status_ids = statuses.filter_map { |status| status["id"]&.to_i }
    return if status_ids.empty?

    reactions_map = build_patchwork_post_reactions(Status.where(id: status_ids).select(:id).to_a)

    statuses.each do |status|
      status_id = status["id"]&.to_i
      status["patchwork_post_reactions"] = reactions_map[status_id] || []
    end

    self.response_body = JSON.generate(payload)
  end

  def json_payload_hash(body)
    JSON.parse(body)
  rescue JSON::ParserError
    nil
  end

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
