# frozen_string_literal: true

# Uploads both email logos by default; brand_color is optional.
# Run from the Mastodon host app root:
#   bundle exec rake newsmast_mastodon:email_branding
#   bundle exec rake 'newsmast_mastodon:email_branding[,header]'
#   bundle exec rake 'newsmast_mastodon:email_branding[,footer]'
#   bundle exec rake 'newsmast_mastodon:email_branding[#D24A34,header]'
namespace :newsmast_mastodon do
  desc "Set email branding color and upload selected email logos (logo: header, footer, or both)"
  task :email_branding, [ :brand_color, :logo ] => :environment do |_task, args|
    logo_files = {
      "mail_header_logo" => "logo-header.png",
      "mail_footer_logo" => "logo-footer.png"
    }
    selected_logo = args[:logo].presence || "both"
    selected_vars =
      case selected_logo
      when "header" then [ "mail_header_logo" ]
      when "footer" then [ "mail_footer_logo" ]
      when "both" then logo_files.keys
      else abort("Invalid logo selection #{selected_logo.inspect}; expected header, footer, or both.")
      end
    logo_files = logo_files.slice(*selected_vars)
    logo_dir = NewsmastMastodon::Engine.root.join("app/assets/images/newsmast_mastodon/email_logos")
    color = args[:brand_color]&.strip

    if color.present? && !color.match?(/\A#(?:\h{3}|\h{6})\z/i)
      abort("Invalid brand_color #{color.inspect}; expected a hex color such as #D24A34.")
    end

    logo_paths = logo_files.to_h do |var, filename|
      path = logo_dir.join(filename)
      unless path.file? && File.binread(path, 8) == "\x89PNG\r\n\x1A\n".b
        abort("Missing or invalid PNG for #{var}: #{path}")
      end

      [ var, path ]
    end

    if color.present?
      setting = Setting.find_or_initialize_by(var: "brand_color")
      setting.value = color
      setting.save!
      puts "Brand color: #{color}"
    else
      puts "Brand color: unchanged"
    end

    logo_paths.each do |var, path|
      upload = SiteUpload.find_or_initialize_by(var: var)

      begin
        File.open(path, "rb") do |file|
          upload.file = file
          upload.save!
        end
      rescue StandardError => error
        safe_message = error.message
                            .gsub(/\b(?:AKIA|ASIA)[A-Z0-9]{16}\b/, "[REDACTED]")
                            .gsub(/(?i)\b[\w-]*(?:secret|token|password|credential|access[_-]?key)[\w-]*(\s*[:=]\s*)[^\s,;]+/, "[REDACTED]")
        abort("Email logo upload failed for #{var} (#{error.class}): #{safe_message}")
      end

      puts "Uploaded #{var}: #{upload.file.url}"
    end
  end
end
