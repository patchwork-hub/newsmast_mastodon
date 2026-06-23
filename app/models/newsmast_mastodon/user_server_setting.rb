# frozen_string_literal: true

module NewsmastMastodon
  class UserServerSetting < ApplicationRecord
    belongs_to :user
    belongs_to :server_setting, class_name: "NewsmastMastodon::ServerSetting"
  end
end
