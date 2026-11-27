# frozen_string_literal: true

class LongPost::DraftedStatusSerializer < ActiveModel::Serializer
  attributes :id, :params

  has_many :media_attachments, serializer: REST::MediaAttachmentSerializer

  def id
    object.id.to_s
  end

  def params
    # jsonb params come back with string keys, so drop both forms.
    object.params.to_h.except("application_id", :application_id)
  end
end
