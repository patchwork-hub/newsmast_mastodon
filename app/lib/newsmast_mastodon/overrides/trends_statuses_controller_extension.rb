# frozen_string_literal: true

module NewsmastMastodon
  module Overrides
    module TrendsStatusesControllerExtension
      include TimelinePatchworkPostReactions

      def index
        super
        decorate_statuses_response!
      end
    end
  end
end