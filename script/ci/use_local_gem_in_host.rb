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

# Finds `gem "newsmast_mastodon", ...` calls anywhere in the file (including
# inside `group`, `platforms` or `if` blocks), with the nodes enclosing each.
def newsmast_gem_calls(node, ancestors = [], found = [])
  if node.is_a?(Prism::CallNode)
    first_arg = node.arguments&.arguments&.first
    if node.receiver.nil? && node.name == :gem && first_arg.is_a?(Prism::StringNode) &&
       first_arg.unescaped == "newsmast_mastodon"
      found << [ node, ancestors ]
    end
  end

  node.compact_child_nodes.each { |child| newsmast_gem_calls(child, ancestors + [ node ], found) }
  found
end

# A modifier `if`/`unless` (`gem "x" if cond`), as opposed to a block form or
# a ternary.
def modifier_condition?(node)
  case node
  when Prism::IfNode then node.if_keyword_loc && node.end_keyword_loc.nil?
  when Prism::UnlessNode then node.end_keyword_loc.nil?
  else false
  end
end

# The source range to remove for a call, and what to put there. A call guarded
# by a modifier condition is removed together with the condition, since
# ` if cond` on its own isn't valid Ruby. Where the call isn't a statement of
# its own (`a && gem ...`), it becomes `nil` so the expression still parses.
def removal_for(node, ancestors)
  target = node
  parents = ancestors.reverse
  while (statements = parents.first).is_a?(Prism::StatementsNode) && statements.body.size == 1 &&
        modifier_condition?(parents[1])
    target = parents[1]
    parents = parents.drop(2)
  end

  text = parents.first.is_a?(Prism::StatementsNode) ? "" : "nil"
  [ target.location.start_offset, target.location.end_offset, text ]
end

calls = newsmast_gem_calls(result.value).sort_by { |node, _| node.location.start_offset }

# Only an entry directly in the Gemfile body is kept in place. One inside a
# block (`group :production do`, `platforms`, `if ...`) or behind a condition
# may be excluded by BUNDLE_WITHOUT or that condition, so it is removed and the
# local entry is added at the top level instead.
top_level = result.value.statements.body
in_place, = calls.find { |node, _| top_level.include?(node) }

edits = calls.map do |node, ancestors|
  if node.equal?(in_place)
    [ node.location.start_offset, node.location.end_offset, replacement ]
  else
    removal_for(node, ancestors)
  end
end

# Drop an edit that lies inside another one's range (the outer edit already
# covers it), then edit from the end so earlier offsets stay valid.
edits = edits.reject do |start, finish, _|
  edits.any? { |other_start, other_finish, _| other_start <= start && finish <= other_finish && [ other_start, other_finish ] != [ start, finish ] }
end

output = source.dup
edits.uniq { |start, finish, _| [ start, finish ] }.sort_by { |start, _, _| -start }.each do |start, finish, text|
  output[start...finish] = text.b
end

output << "\n" unless output.empty? || output.end_with?("\n")
output << "\n#{replacement}\n".b unless in_place

rewritten = Prism.parse(output)
abort("Rewritten Gemfile does not parse: #{rewritten.errors.map(&:message).join("; ")}") unless rewritten.success?

File.binwrite(gemfile, output)
puts "Host Gemfile now uses newsmast_mastodon from #{gem_path}#{in_place ? "" : " (added at the top level)"}"
