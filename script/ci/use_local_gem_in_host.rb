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
# Further entries for the gem are removed.

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

output = source.dup
# Edit from the end so earlier offsets stay valid. The first entry becomes the
# path entry; any later ones are removed.
calls.each_with_index.reverse_each do |node, index|
  location = node.location
  output[location.start_offset...location.end_offset] = index.zero? ? replacement.b : "".b
end

output << "\n" unless output.empty? || output.end_with?("\n")
output << "\n#{replacement}\n".b if calls.empty?

rewritten = Prism.parse(output)
abort("Rewritten Gemfile does not parse: #{rewritten.errors.map(&:message).join("; ")}") unless rewritten.success?

File.binwrite(gemfile, output)
puts "Host Gemfile now uses newsmast_mastodon from #{gem_path}#{calls.empty? ? " (appended)" : ""}"
