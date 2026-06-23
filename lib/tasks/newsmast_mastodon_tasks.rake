# frozen_string_literal: true

# The primary `newsmast_mastodon:install` task lives in
# `lib/tasks/newsmast_mastodon/install.rake`. This file adds an inverse
# `newsmast_mastodon:uninstall` task to remove copied files + marker.

require "fileutils"

namespace :newsmast_mastodon do
  desc "Remove newsmast_mastodon overrides previously copied into the host app."
  task uninstall: :environment do
    rails_root = Rails.root
    spec = Gem.loaded_specs["newsmast_mastodon"]
    gem_root = spec&.full_gem_path

    removed = 0

    # Chewy
    if gem_root && Dir.exist?(File.join(gem_root, "app/chewy/newsmast_mastodon"))
      Dir.glob(File.join(gem_root, "app/chewy/newsmast_mastodon/*.rb")).each do |src|
        dst = rails_root.join("app/chewy", File.basename(src))
        if File.exist?(dst)
          File.delete(dst)
          removed += 1
          puts "removed #{dst.sub(rails_root.to_s + '/', '')}"
        end
      end
    end

    # JS
    if gem_root
      js_src_root = File.join(gem_root, "app/javascript/newsmast_mastodon/mastodon")
      Dir.glob(File.join(js_src_root, "**/*")).each do |src|
        next unless File.file?(src)

        rel = src.sub(js_src_root + "/", "")
        dst = rails_root.join("app/javascript/mastodon", rel)
        if File.exist?(dst)
          File.delete(dst)
          removed += 1
          puts "removed app/javascript/mastodon/#{rel}"
        end
      end
    end

    # Views
    %w[admin/shared/_status.html.haml].each do |rel|
      dst = rails_root.join("app/views", rel)
      if File.exist?(dst)
        File.delete(dst)
        removed += 1
        puts "removed app/views/#{rel}"
      end
    end

    marker_path = rails_root.join(".newsmast_mastodon_installed")
    if File.exist?(marker_path)
      File.delete(marker_path)
      puts "removed .newsmast_mastodon_installed"
    end

    puts "\nUninstalled #{removed} file(s)."
  end
end
