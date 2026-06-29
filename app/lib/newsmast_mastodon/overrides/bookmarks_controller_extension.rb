# frozen_string_literal: true

module NewsmastMastodon
  module Overrides
    module BookmarksControllerExtension
      include TimelinePatchworkPostReactions

      def index
        super
        decorate_statuses_response!
      end
    end
  end
end
