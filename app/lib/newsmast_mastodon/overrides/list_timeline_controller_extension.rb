# frozen_string_literal: true

module NewsmastMastodon
  module Overrides
    module ListTimelineControllerExtension
      include TimelinePatchworkPostReactions

      def show
        super
        decorate_statuses_response!
      end
    end
  end
end