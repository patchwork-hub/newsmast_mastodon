# frozen_string_literal: true

# Points a host Mastodon checkout at this gem's local source, so CI tests the
# code in this repository instead of whatever version the host Gemfile pins.
#
# Usage: ruby script/ci/use_local_gem_in_host.rb <host_root> <gem_root>
#
# Replaces the `gem "newsmast_mastodon", ...` entry in <host_root>/Gemfile
# (including options continued on following lines) with a `path:` entry, or
# appends one if the host doesn't list the gem. Run `bundle install` afterwards
# with frozen mode off so the lockfile is re-resolved.

host_root, gem_root = ARGV
abort("Usage: #{$PROGRAM_NAME} <host_root> <gem_root>") if host_root.to_s.empty? || gem_root.to_s.empty?

gemfile = File.join(host_root, "Gemfile")
abort("Host Gemfile not found: #{gemfile}") unless File.file?(gemfile)

gem_path = File.expand_path(gem_root)
replacement = "gem \"newsmast_mastodon\", path: #{gem_path.inspect}\n"

lines = File.readlines(gemfile)
output = []
replaced = false
skipping_continuation = false

lines.each do |line|
  if skipping_continuation
    skipping_continuation = line.rstrip.end_with?(",")
    next
  end

  if line =~ /\A\s*gem\s+["']newsmast_mastodon["']/
    output << replacement unless replaced
    replaced = true
    skipping_continuation = line.rstrip.end_with?(",")
    next
  end

  output << line
end

output << "\n#{replacement}" unless replaced

File.write(gemfile, output.join)
puts "Host Gemfile now uses newsmast_mastodon from #{gem_path}#{replaced ? "" : " (appended)"}"
