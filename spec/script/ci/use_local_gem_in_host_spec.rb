# frozen_string_literal: true

require "open3"
require "prism"
require "rbconfig"
require "tmpdir"

RSpec.describe "script/ci/use_local_gem_in_host.rb" do
  let(:script) { File.expand_path("../../../script/ci/use_local_gem_in_host.rb", __dir__) }
  let(:gem_root) { "/checkout/gem" }
  let(:entry) { %(gem "newsmast_mastodon", path: "/checkout/gem") }

  def rewrite(gemfile)
    Dir.mktmpdir do |host_root|
      path = File.join(host_root, "Gemfile")
      File.write(path, gemfile)
      _out, err, status = Open3.capture3(RbConfig.ruby, script, host_root, gem_root)
      raise "script failed: #{err}" unless status.success?

      File.read(path)
    end
  end

  def expect_valid_ruby(source)
    result = Prism.parse(source)
    expect(result.errors.map(&:message)).to be_empty
  end

  it "replaces a single-line entry" do
    output = rewrite(<<~RUBY)
      source "https://rubygems.org"
      gem "rails"
      gem "newsmast_mastodon", "~> 4.6"
      gem "pg"
    RUBY

    expect(output).to eq(<<~RUBY)
      source "https://rubygems.org"
      gem "rails"
      #{entry}
      gem "pg"
    RUBY
  end

  it "replaces an entry whose options continue on the following lines" do
    output = rewrite(<<~RUBY)
      gem "newsmast_mastodon",
          git: "https://example.org/newsmast_mastodon.git",
          branch: "main"
      gem "pg"
    RUBY

    expect(output).to eq("#{entry}\ngem \"pg\"\n")
  end

  it "replaces an entry with a trailing comment after the comma" do
    output = rewrite(<<~RUBY)
      gem "newsmast_mastodon", # customization
          git: "https://example.org/newsmast_mastodon.git"
      gem "pg"
    RUBY

    expect_valid_ruby(output)
    expect(output).to eq("#{entry}\ngem \"pg\"\n")
  end

  it "replaces an entry continued across blank and comment-only lines" do
    output = rewrite(<<~RUBY)
      gem "newsmast_mastodon",

          # pinned for the 4.6 line
          git: "https://example.org/newsmast_mastodon.git",
          # main branch
          branch: "main"
      gem "pg"
    RUBY

    expect_valid_ruby(output)
    expect(output).to eq("#{entry}\ngem \"pg\"\n")
  end

  it "moves an entry out of a production group so a test bundle includes it" do
    output = rewrite(<<~RUBY)
      source "https://rubygems.org"
      group :production do
        gem 'newsmast_mastodon', '4.6.5.1' # Newsmast features
      end
    RUBY

    expect_valid_ruby(output)
    expect(output).to eq(<<~RUBY)
      source "https://rubygems.org"
      group :production do
         # Newsmast features
      end

      #{entry}
    RUBY

    # Host integration bundles with BUNDLE_WITHOUT=development:production.
    expect(bundler_groups(output)).to eq([ :default ])
  end

  it "moves an entry out of a conditional block" do
    output = rewrite(<<~RUBY)
      if ENV["NEWSMAST"]
        gem "newsmast_mastodon"
      end
    RUBY

    expect_valid_ruby(output)
    expect(output).to end_with("end\n\n#{entry}\n")
    expect(bundler_groups(output)).to eq([ :default ])
  end

  it "keeps a top-level entry in place when another entry is in a group" do
    output = rewrite(<<~RUBY)
      group :production do
        gem "newsmast_mastodon", "4.6.5.1"
      end
      gem "newsmast_mastodon", "~> 4.6"
      gem "pg"
    RUBY

    expect_valid_ruby(output)
    expect(output).to eq("group :production do\n  \nend\n#{entry}\ngem \"pg\"\n")
  end

  # The groups Bundler assigns to newsmast_mastodon when evaluating the Gemfile.
  def bundler_groups(gemfile)
    require "bundler"

    Dir.mktmpdir do |dir|
      path = File.join(dir, "Gemfile")
      File.write(path, gemfile.gsub(gem_root, dir))
      dsl = Bundler::Dsl.new
      dsl.eval_gemfile(path)
      dsl.dependencies.find { |dependency| dependency.name == "newsmast_mastodon" }&.groups
    end
  end

  it "keeps the first entry and removes later ones" do
    output = rewrite(<<~RUBY)
      gem "newsmast_mastodon", "~> 4.6"
      gem "pg"
      gem "newsmast_mastodon",
          path: "../other"
    RUBY

    expect_valid_ruby(output)
    expect(output.scan("newsmast_mastodon").size).to eq(1)
    expect(output).to start_with("#{entry}\ngem \"pg\"\n")
  end

  it "does not touch gems whose names only start with newsmast_mastodon" do
    output = rewrite(%(gem "newsmast_mastodon_extras"\n))

    expect(output).to eq(%(gem "newsmast_mastodon_extras"\n\n#{entry}\n))
  end

  it "appends an entry when the host doesn't list the gem" do
    output = rewrite(%(gem "pg"))

    expect(output).to eq(%(gem "pg"\n\n#{entry}\n))
  end
end
