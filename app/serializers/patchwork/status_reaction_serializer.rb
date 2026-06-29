# frozen_string_literal: true

module Patchwork
  class StatusReactionSerializer < ActiveModel::Serializer
    attributes :name, :count

    attribute :me, if: :current_user?

    def count
      object.respond_to?(:count) ? object.count : 0
    end

    def current_user?
      !current_user.nil?
    end

    def me
      object.respond_to?(:me) ? object.me : false
    end
  end
end
