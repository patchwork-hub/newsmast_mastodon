# frozen_string_literal: true

module NewsmastMastodon::Api::V1::Patchwork
  class ConversationsController < ::Api::BaseController
    LIMIT = 1

    before_action -> { doorkeeper_authorize! :read, :'read:statuses' }, only: :check_conversation
    before_action -> { doorkeeper_authorize! :write, :'write:conversations' }, except: :check_conversation
    before_action -> { doorkeeper_authorize! :write, :'write:conversations' }, only: :read_all
    before_action :require_user!

    def check_conversation
      @conversations = paginated_conversations
      return render json: {}, status: 200 unless @conversations.any?

      render json: @conversations.last, serializer: REST::ConversationSerializer, relationships: StatusRelationshipsPresenter.new(@conversations.map(&:last_status), current_user&.account_id)
    end

    def read_all
      @conversations = AccountConversation.where(account: current_account, unread: true)
      updated_count = @conversations.update_all(unread: false)

      render json: { success: true,
      updated_count: updated_count,
      message: "Marked #{updated_count} conversation(s) as read" }, each_serializer: REST::ConversationSerializer, relationships: StatusRelationshipsPresenter.new(@conversations.map(&:last_status), current_user&.account_id)
    end

    private

      def paginated_conversations
        return [] if params[:target_account_id].blank?

        account_conversation = AccountConversation
                              .where(account: current_account)
                              .where(participant_account_ids: [ params[:target_account_id] ])

        return [] if account_conversation.blank?

        account_conversation
          .includes(
            account: [ :account_stat, user: :role ],
            last_status: [
              :media_attachments,
              :status_stat,
              :tags,
              {
                preview_cards_status: { preview_card: { author_account: [ :account_stat, user: :role ] } },
                active_mentions: :account,
                account: [ :account_stat, user: :role ]
              }
            ]
          )
          .to_a_paginated_by_id(limit_param(LIMIT), params_slice(:max_id, :since_id, :min_id))
      end
  end
end
