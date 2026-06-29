# frozen_string_literal: true

module LocalOnlyPosts::StatusSerializerExtension
  extend ActiveSupport::Concern

  included do
    attributes :local_only
    attribute :patchwork_post_reactions, if: :include_patchwork_post_reactions?
  end

  def include_patchwork_post_reactions?
    instance_options[:include_patchwork_post_reactions] == true
  end

  def patchwork_post_reactions
    instance_options[:patchwork_post_reactions]&.fetch(object.id, []) || []
  end
end
