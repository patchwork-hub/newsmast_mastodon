module NewsmastMastodon::Api::V1
  class LocalOnlyPostsController < ::Api::BaseController
    include Authorization if defined?(Authorization)
    before_action :require_user!, only: [ :getLocalOnlySetting ]

    def getLocalOnlySetting
      # Early return if NewsmastMastodon::ServerSetting doesn't exist
      unless Object.const_defined?("NewsmastMastodon::ServerSetting")
        return render json: { local_only: false }, status: :ok
      end

      setting = NewsmastMastodon::ServerSetting.find_by(name: "Local only posts")
      return render json: { local_only: false }, status: :ok if setting.nil?

      render json: { local_only: setting.value }, status: :ok
    end
  end
end
