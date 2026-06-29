# frozen_string_literal: true

module NewsmastMastodon::Api::V1::Patchwork
  class StatusReactionsController < ::Api::BaseController
    include ::NewsmastMastodon::Concerns::ApiResponseHelper

    before_action -> { doorkeeper_authorize! :write, :'write:favourites' }
    before_action :require_user!
    before_action :set_status

    def update
      reaction = NewsmastMastodon::PatchworkStatusReaction.find_or_initialize_by(
        account: current_account,
        status: @status
      )
      reaction.name = params[:id]

      if reaction.save
        render_success(
          serialize_reaction(reaction),
          "api.messages.success",
          :ok
        )
      else
        render_validation_failed(reaction.errors)
      end
    end

    def destroy
      reaction = NewsmastMastodon::PatchworkStatusReaction.find_by(
        account: current_account,
        status: @status,
        name: params[:id]
      )

      if reaction.present?
        reaction.destroy!
        render_success(nil, "api.messages.deleted", :ok)
      else
        render_error(
          "api.errors.not_found",
          :not_found
        )
      end
    end

    private

    def set_status
      @status = Status.find(params[:status_id])
    rescue ActiveRecord::RecordNotFound
      render_error("api.errors.not_found", :not_found)
    end

    def serialize_reaction(reaction)
      {
        name: reaction.name,
        created_at: reaction.created_at
      }
    end
  end
end
