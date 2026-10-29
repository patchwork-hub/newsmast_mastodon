# GEM_SPLIT[MEDIA-02]: Migrated to patchwork_extensions (Gem B) as
# PatchworkExtensions::Api::V1::UtilitiesController. Gem A routes for this
# controller are disabled in config/routes.rb; remove this controller and the
# commented routes block after the verification window.
module NewsmastMastodon::Api::V1
  class UtilitiesController < ::Api::BaseController
    def link_preview
      url = params[:url]
      unless url.present?
        return render json: { error: "URL must be present" }, status: :bad_request
      end

      data = NewsmastMastodon::FetchLinkMetadataService.new.call(url)
      render json: data, status: :ok
    rescue NewsmastMastodon::FetchLinkMetadataService::InvalidURLError => e
      render json: { error: e.message }, status: :bad_request
    rescue NewsmastMastodon::FetchLinkMetadataService::FetchError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
