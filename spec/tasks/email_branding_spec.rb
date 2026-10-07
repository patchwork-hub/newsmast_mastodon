# frozen_string_literal: true

require "rails_helper"
require "rake"
require "fileutils"
require "stringio"
require "tmpdir"

RSpec.describe "newsmast_mastodon:email_branding" do
  let(:task) { Rake::Task["newsmast_mastodon:email_branding"] }

  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("newsmast_mastodon:email_branding")
    task.reenable
  end

  it "updates the color and uploads both logos" do
    Dir.mktmpdir do |directory|
      logo_dir = Pathname.new(directory).join("app/assets/images/newsmast_mastodon/email_logos")
      FileUtils.mkdir_p(logo_dir)
      %w[logo-header.png logo-footer.png].each do |filename|
        File.binwrite(logo_dir.join(filename), "\x89PNG\r\n\x1A\n".b)
      end
      allow(NewsmastMastodon::Engine).to receive(:root).and_return(Pathname.new(directory))

      setting = double("Setting", save!: true)
      allow(setting).to receive(:value=)
      setting_class = Class.new do
        def self.find_or_initialize_by(*) = nil
      end
      allow(setting_class).to receive(:find_or_initialize_by).with(var: "brand_color").and_return(setting)
      stub_const("Setting", setting_class)

      uploads = %w[mail_header_logo mail_footer_logo].to_h do |var|
        attachment = double(url: "https://assets.example/#{var}.png")
        upload = double(file: attachment, save!: true)
        allow(upload).to receive(:file=)
        [ var, upload ]
      end
      upload_class = Class.new do
        def self.find_or_initialize_by(*) = nil
      end
      expect(upload_class).to receive(:find_or_initialize_by).with(var: "mail_header_logo").and_return(uploads.fetch("mail_header_logo"))
      expect(upload_class).to receive(:find_or_initialize_by).with(var: "mail_footer_logo").and_return(uploads.fetch("mail_footer_logo"))
      stub_const("SiteUpload", upload_class)

      expect(setting).to receive(:value=).with("#D24A34")
      expect(setting).to receive(:save!)
      uploads.each_value { |upload| expect(upload).to receive(:save!) }

      task.invoke("#D24A34")
    end
  end

  it "rejects an invalid color before writing records" do
    expect { task.invoke("red") }.to raise_error(SystemExit)
  end

  it "updates only the selected header logo" do
    Dir.mktmpdir do |directory|
      logo_dir = Pathname.new(directory).join("app/assets/images/newsmast_mastodon/email_logos")
      FileUtils.mkdir_p(logo_dir)
      File.binwrite(logo_dir.join("logo-header.png"), "\x89PNG\r\n\x1A\n".b)
      allow(NewsmastMastodon::Engine).to receive(:root).and_return(Pathname.new(directory))

      upload = double(file: double(url: "https://assets.example/header.png"), save!: true)
      allow(upload).to receive(:file=)
      upload_class = Class.new do
        def self.find_or_initialize_by(*) = nil
      end
      expect(upload_class).to receive(:find_or_initialize_by).with(var: "mail_header_logo").and_return(upload)
      expect(upload_class).not_to receive(:find_or_initialize_by).with(var: "mail_footer_logo")
      stub_const("SiteUpload", upload_class)

      task.invoke("", "header")
    end
  end

  it "updates only the selected footer logo" do
    Dir.mktmpdir do |directory|
      logo_dir = Pathname.new(directory).join("app/assets/images/newsmast_mastodon/email_logos")
      FileUtils.mkdir_p(logo_dir)
      File.binwrite(logo_dir.join("logo-footer.png"), "\x89PNG\r\n\x1A\n".b)
      allow(NewsmastMastodon::Engine).to receive(:root).and_return(Pathname.new(directory))

      upload = double(file: double(url: "https://assets.example/footer.png"), save!: true)
      allow(upload).to receive(:file=)
      upload_class = Class.new do
        def self.find_or_initialize_by(*) = nil
      end
      expect(upload_class).not_to receive(:find_or_initialize_by).with(var: "mail_header_logo")
      expect(upload_class).to receive(:find_or_initialize_by).with(var: "mail_footer_logo").and_return(upload)
      stub_const("SiteUpload", upload_class)

      task.invoke("", "footer")
    end
  end

  it "rejects an invalid logo selection before writing records" do
    expect { task.invoke("", "side") }.to raise_error(SystemExit)
  end

  it "rejects missing logo assets before writing records" do
    Dir.mktmpdir do |directory|
      allow(NewsmastMastodon::Engine).to receive(:root).and_return(Pathname.new(directory))

      expect { task.invoke }.to raise_error(SystemExit)
    end
  end

  it "keeps the first upload when the second upload fails" do
    Dir.mktmpdir do |directory|
      logo_dir = Pathname.new(directory).join("app/assets/images/newsmast_mastodon/email_logos")
      FileUtils.mkdir_p(logo_dir)
      %w[logo-header.png logo-footer.png].each do |filename|
        File.binwrite(logo_dir.join(filename), "\x89PNG\r\n\x1A\n".b)
      end
      allow(NewsmastMastodon::Engine).to receive(:root).and_return(Pathname.new(directory))

      successful_upload = double(file: double(url: "https://assets.example/header.png"))
      failing_upload = double(file: double(url: "https://assets.example/footer.png"))
      [ successful_upload, failing_upload ].each { |upload| allow(upload).to receive(:file=) }
      allow(successful_upload).to receive(:save!)
      allow(failing_upload).to receive(:save!).and_raise(StandardError, "AWS_SECRET_ACCESS_KEY=secret-value")

      upload_class = Class.new do
        def self.find_or_initialize_by(*) = nil
      end
      allow(upload_class).to receive(:find_or_initialize_by).with(var: "mail_header_logo").and_return(successful_upload)
      allow(upload_class).to receive(:find_or_initialize_by).with(var: "mail_footer_logo").and_return(failing_upload)
      stub_const("SiteUpload", upload_class)

      expect(successful_upload).to receive(:save!)
      expect(failing_upload).to receive(:save!)
      original_stderr = $stderr
      $stderr = StringIO.new
      expect { task.invoke }.to raise_error(SystemExit)
      expect($stderr.string).to include("[REDACTED]")
      expect($stderr.string).not_to include("secret-value")
    ensure
      $stderr = original_stderr
    end
  end
end
