# frozen_string_literal: true

module NewsmastMastodon
  module Concerns
    module SearchControllerExtension
      extend ActiveSupport::Concern

      include NewsmastMastodon::Overrides::TimelinePatchworkPostReactions

      def index
        super
        decorate_search_statuses_response!
      end

      private

      def decorate_search_statuses_response!
        payload = json_payload_hash(response.body)
        return if payload.blank?

        statuses = Array(payload['statuses'])
        return if statuses.empty?

        status_ids = statuses.filter_map { |status| status['id']&.to_i }
        return if status_ids.empty?

        reactions_map = build_patchwork_post_reactions(Status.where(id: status_ids).select(:id).to_a)

        statuses.each do |status|
          status_id = status['id']&.to_i
          status['patchwork_post_reactions'] = reactions_map[status_id] || []
        end

        self.response_body = JSON.generate(payload)
      end

      def json_payload_hash(body)
        JSON.parse(body)
      rescue JSON::ParserError
        nil
      end

      def search_params
        params.permit(:type, :offset, :min_id, :max_id, :account_id, :following, :local_only)
      end

      def combined_search_params
        super.merge(local_only: truthy_param?(:local_only))
      end
    end
  end
end
