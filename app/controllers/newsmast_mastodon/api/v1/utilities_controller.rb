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
