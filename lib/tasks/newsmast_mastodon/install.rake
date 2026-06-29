# frozen_string_literal: true

# Install task: copy Chewy indexes and frontend overrides from the
# newsmast_mastodon gem into the host Mastodon application.
require "fileutils"

namespace :newsmast_mastodon do
  desc "Install newsmast_mastodon Chewy indexes and frontend overrides into the host Mastodon app"
  task install: :environment do
    # Verify running in a Mastodon host app context
    unless Object.const_defined?("Mastodon::Version")
      abort(
        "ERROR: newsmast_mastodon:install must be run in a Mastodon host application.\n" \
        "This command copies UI-related files and Chewy indexes from the gem into the host app.\n" \
        "\n" \
        "Setup steps:\n" \
        "  1. Add to your Mastodon app's Gemfile:\n" \
        "       gem 'newsmast_mastodon', '4.5.11'\n" \
        "  2. Run: bundle install\n" \
        "  3. Run: bin/rails newsmast_mastodon:install\n" \
        "  4. Run: bin/rails db:migrate\n"
      )
    end

    spec = Gem.loaded_specs["newsmast_mastodon"]
    abort "newsmast_mastodon gem not found" unless spec

    gem_root = spec.full_gem_path

    install_chewy_indexes!(gem_root)
    install_frontend_overrides!(gem_root)
    create_marker_file!

    puts "\nnewsmast_mastodon has been successfully installed."
    puts "\n" + "=" * 70
    puts "NEXT STEPS"
    puts "=" * 70
    puts "1. Run database migrations:"
    puts "     bin/rails db:migrate"
    puts "\n2. Rebuild frontend assets with the updated files:"
    puts "     yarn build:development  # or yarn build:production"
    puts "\n3. Restart your Mastodon instance"
    puts "=" * 70
  end

  # =============================================
  # Chewy indexes installation
  # =============================================
  def install_chewy_indexes!(gem_root)
    source_path      = File.join(gem_root, "app", "chewy", "newsmast_mastodon")
    destination_path = Rails.root.join("app", "chewy")

    unless Dir.exist?(source_path)
      puts "Skipping Chewy install (source directory not found: #{source_path})"
      return
    end

    FileUtils.mkdir_p(destination_path)
    puts "Copying and transforming Chewy index files from newsmast_mastodon gem..."

    Dir.glob(File.join(source_path, "*.rb")).each do |file|
      filename         = File.basename(file)
      destination_file = File.join(destination_path, filename)

      # Strip the NewsmastMastodon:: namespace so the host app consumes the
      # indexes as top-level constants.
      content             = File.read(file)
      transformed_content = content.gsub(/class\s+NewsmastMastodon::(\w+Index)\s+</, 'class \1 <')

      File.write(destination_file, transformed_content)
      puts "  ✓ Transformed #{filename}"
    end

    puts "✓ Chewy indexes copied to #{destination_path}/"
  end

  # =============================================
  # Frontend overrides installation
  # =============================================
  def install_frontend_overrides!(gem_root)
    overrides = [
      {
        label:       "JS",
        source_root: File.join(gem_root, "app/javascript/newsmast_mastodon/mastodon"),
        target_root: Rails.root.join("app/javascript/mastodon"),
        files:       {
          "actions/compose.js"                                            => "actions/compose.js",
          "reducers/compose.js"                                           => "reducers/compose.js",
          "features/compose/components/compose_form.jsx"                  => "features/compose/components/compose_form.jsx",
          "features/compose/containers/compose_form_container.js"         => "features/compose/containers/compose_form_container.js",
          "features/status/components/detailed_status.tsx"                => "features/status/components/detailed_status.tsx",
          "features/compose/components/federated_dropdown.jsx"            => "features/compose/components/federated_dropdown.jsx",
          "features/compose/containers/federated_dropdown_container.js"   => "features/compose/containers/federated_dropdown_container.js"
        }
      },
      {
        label:       "VIEW",
        source_root: File.join(gem_root, "app/views"),
        target_root: Rails.root.join("app/views"),
        files:       {
          "admin/shared/_status.html.haml" => "admin/shared/_status.html.haml"
        }
      }
    ]

    puts "\nApplying newsmast_mastodon frontend overrides..."

    missing_files = []

    overrides.each do |group|
      puts "\n#{group[:label]} overrides"

      group[:files].each do |source_rel, target_rel|
        source = File.join(group[:source_root], source_rel)
        target = File.join(group[:target_root], target_rel)

        unless File.exist?(source)
          puts "  ❌ Missing: #{source_rel}"
          missing_files << { group: group[:label], file: source_rel, path: source }
          next
        end

        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp(source, target)

        puts "  ✓ Copied: #{target_rel}"
      end
    end

    # Fail if critical UI files are missing
    if missing_files.any?
      puts "\n" + "=" * 70
      puts "ERROR: Missing critical UI files"
      puts "=" * 70
      missing_files.each do |file_info|
        puts "  - [#{file_info[:group]}] #{file_info[:file]}"
        puts "    Path: #{file_info[:path]}"
      end
      abort(
        "\nThe newsmast_mastodon gem appears to be incomplete or corrupted.\n" \
        "Please verify the gem installation and try again."
      )
    end
  end

  def create_marker_file!
    marker_path = Rails.root.join(".newsmast_mastodon_installed")
    File.write(marker_path, <<~CONTENT)
      # This file indicates that newsmast_mastodon has been installed
      # Generated at: #{Time.current}
      # Do not delete this file unless you want to re-run the installation
    CONTENT
    puts "✓ Created installation marker: .newsmast_mastodon_installed"
  end
end

# ============================================
# Backward-compatibility aliases
# ============================================
# These tasks maintain compatibility with existing documentation
# and scripts that use older task names.

namespace :local_only_posts do
  desc "Alias: Install local_only_posts features (delegates to newsmast_mastodon:install)"
  task install: "newsmast_mastodon:install"
end

namespace :content_filters do
  desc "Alias: Install content_filters features (delegates to newsmast_mastodon:install)"
  task install: "newsmast_mastodon:install"
end
