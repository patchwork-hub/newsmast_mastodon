# frozen_string_literal: true

Rails.application.config.to_prepare do
  NewsmastMastodon::Engine.paths["app/views"].existent.each do |path|
    ActionMailer::Base.prepend_view_path path
  end
end
