# frozen_string_literal: true

module MoMeHelper
  extend ActiveSupport::Concern

  def is_mo_me?
    return true if Rails.env.development?

    return true if ENV.fetch("LOCAL_DOMAIN", nil) == "mo-me.social"

    false
  end
end
