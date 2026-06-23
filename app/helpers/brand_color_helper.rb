# frozen_string_literal: true

module BrandColorHelper
  def brand_color
    setting = Setting.find_by(var: "brand_color")

    # mastodon default color #6364ff
    setting&.value.presence || "#6364ff"
  end
end
