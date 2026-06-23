# frozen_string_literal: true

module LogoHelper
  def mail_header_logo_image_url
    site_upload = SiteUpload.find_by(var: "mail_header_logo")

    return "" unless site_upload&.file&.respond_to?(:url)

    generate_image_url(site_upload)
  end

  def mail_footer_logo_image_url
    site_upload = SiteUpload.find_by(var: "mail_footer_logo")

    return "" unless site_upload&.file&.respond_to?(:url)

    generate_image_url(site_upload)
  end

  def generate_image_url(image)
    file_url  = image.file.url
    timestamp = image.updated_at&.to_i
    "#{file_url}?#{timestamp}"
  end
end
