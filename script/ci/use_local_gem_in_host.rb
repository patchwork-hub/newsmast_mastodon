# frozen_string_literal: true

# Points a host Mastodon checkout at this gem's local source, so CI tests the
# code in this repository instead of whatever version the host Gemfile pins.
#
# Usage: ruby script/ci/use_local_gem_in_host.rb <host_root> <gem_root>
#
# Replaces the `gem "newsmast_mastodon", ...` entry in <host_root>/Gemfile with
# a `path:` entry, or appends one if the host doesn't list the gem. Run
# `bundle install` afterwards with frozen mode off so the lockfile is
# re-resolved.
#
# The Gemfile is parsed with Prism, so an entry whose options continue on later
# lines (including across blank lines and comments, or after a trailing
# comment such as `gem "newsmast_mastodon", # pinned`) is replaced as a whole.
# Further entries for the gem are removed, and an entry nested in a block (such
# as `group :production`, which CI excludes with BUNDLE_WITHOUT) is replaced by
# a top-level one.

require "prism"

host_root, gem_root = ARGV
abort("Usage: #{$PROGRAM_NAME} <host_root> <gem_root>") if host_root.to_s.empty? || gem_root.to_s.empty?

gemfile = File.join(host_root, "Gemfile")
abort("Host Gemfile not found: #{gemfile}") unless File.file?(gemfile)

gem_path = File.expand_path(gem_root)
replacement = "gem \"newsmast_mastodon\", path: #{gem_path.inspect}"

source = File.binread(gemfile)
result = Prism.parse(source)
abort("Host Gemfile does not parse: #{result.errors.map(&:message).join("; ")}") unless result.success?

# Finds top-level-style `gem "newsmast_mastodon", ...` calls anywhere in the
# file (including inside `group`, `platforms` or `if` blocks).
class NewsmastGemCalls < Prism::Visitor
  attr_reader :calls

  def initialize
    @calls = []
    super
  end

  def visit_call_node(node)
    first_arg = node.arguments&.arguments&.first
    if node.receiver.nil? && node.name == :gem && first_arg.is_a?(Prism::StringNode) &&
       first_arg.unescaped == "newsmast_mastodon"
      @calls << node
    end

    super
  end
end

visitor = NewsmastGemCalls.new
result.value.accept(visitor)
calls = visitor.calls.sort_by { |node| node.location.start_offset }

# Only an entry directly in the Gemfile body is kept in place. One inside a
# block (`group :production do`, `platforms`, `if ...`) may be excluded by
# BUNDLE_WITHOUT or a condition, so it is removed and the local entry is added
# at the top level instead.
top_level = result.value.statements.body
in_place = calls.find { |node| top_level.include?(node) }

output = source.dup
# Edit from the end so earlier offsets stay valid.
calls.reverse_each do |node|
  location = node.location
  output[location.start_offset...location.end_offset] = node.equal?(in_place) ? replacement.b : "".b
end

output << "\n" unless output.empty? || output.end_with?("\n")
output << "\n#{replacement}\n".b unless in_place

rewritten = Prism.parse(output)
abort("Rewritten Gemfile does not parse: #{rewritten.errors.map(&:message).join("; ")}") unless rewritten.success?

File.binwrite(gemfile, output)
puts "Host Gemfile now uses newsmast_mastodon from #{gem_path}#{in_place ? "" : " (added at the top level)"}"
