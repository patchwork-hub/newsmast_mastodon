# frozen_string_literal: true

module NewsmastMastodon
  module Overrides
    module TimelinePatchworkPostReactions
      private

      def decorate_statuses_response!
        payload = json_payload_array(response.body)
        return if payload.empty?

        status_ids = payload.filter_map { |status| status['id']&.to_i }
        return if status_ids.empty?

        reactions_map = build_patchwork_post_reactions(Status.where(id: status_ids).select(:id).to_a)

        payload.each do |status|
          status_id = status['id']&.to_i
          status['patchwork_post_reactions'] = reactions_map[status_id] || []
        end

        self.response_body = JSON.generate(payload)
      end

      def json_payload_array(body)
        parsed = JSON.parse(body)
        parsed.is_a?(Array) ? parsed : []
      rescue JSON::ParserError
        []
      end

      def build_patchwork_post_reactions(statuses, account: current_account)
        status_ids = statuses.map(&:id)
        return {} if status_ids.empty?

        grouped_counts = NewsmastMastodon::PatchworkStatusReaction
                         .where(status_id: status_ids)
                         .group(:status_id, :name)
                         .count

        my_reactions = build_my_reactions_map(status_ids, account)

        grouped_counts.each_with_object(Hash.new { |h, k| h[k] = [] }) do |((status_id, name), count), acc|
          acc[status_id] << {
            name: name,
            count: count,
            me: my_reactions[status_id] == name,
          }
        end.tap do |result|
          result.each_value do |reactions|
            reactions.sort_by! { |reaction| [-reaction[:count], reaction[:name]] }
          end
        end
      end

      def build_my_reactions_map(status_ids, account)
        return {} unless account.present?

        NewsmastMastodon::PatchworkStatusReaction
          .where(status_id: status_ids, account_id: account.id)
          .pluck(:status_id, :name)
          .to_h
      end
    end
  end
end