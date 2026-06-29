# frozen_string_literal: true

class PatchworkStatusReactionValidator < ActiveModel::Validator
  ALLOWED_REACTIONS = (ENV['PATCHWORK_STATUS_REACTION_NAMES'] || '👍,❤️,😂,😮,😠')
                        .split(',')
                        .map(&:strip)
                        .freeze

  EMOJI_LIMIT = (ENV['PATCHWORK_STATUS_REACTION_EMOJI_LIMIT'] || '5').to_i

  def validate(reaction)
    return if reaction.name.blank?

    unless ALLOWED_REACTIONS.include?(reaction.name)
      reaction.errors.add(:name, I18n.t('patchwork_status_reactions.errors.unrecognized_reaction'))
    end

    if ALLOWED_REACTIONS.size > EMOJI_LIMIT
      reaction.errors.add(:base, I18n.t('patchwork_status_reactions.errors.emoji_limit_exceeded'))
    end
  end
end
