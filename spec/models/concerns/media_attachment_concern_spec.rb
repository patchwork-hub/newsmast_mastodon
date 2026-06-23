# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe NewsmastMastodon::Concerns::MediaAttachmentConcern, type: :model do
  let(:host_class) do
    klass = Class.new do
      class << self
        def belongs_to(*); end
        def scope(*args, &block); end
        def after_save(*); end
      end

      attr_accessor :file_content_type, :description, :status_id, :remote_url

      def initialize(content_type: nil, description: nil)
        @file_content_type = content_type
        @description = description
      end
    end
    klass.include(described_class)
    klass
  end

  it "#is_valid_content_type? returns true for IMAGE_ALLOW_TYPES" do
    instance = host_class.new(content_type: "image/jpeg")
    expect(instance.is_valid_content_type?).to be true
  end

  it "#is_valid_content_type? returns false for non-image types" do
    instance = host_class.new(content_type: "video/mp4")
    expect(instance.is_valid_content_type?).to be false
  end

  it "IMAGE_ALLOW_TYPES includes standard web image formats" do
    instance = host_class.new
    # constant is defined on host class via included block
    expect(host_class::IMAGE_ALLOW_TYPES).to include("image/jpeg", "image/png", "image/gif", "image/webp")
  end

  it "#can_generate_alt? returns false when description already present" do
    instance = host_class.new(content_type: "image/jpeg", description: "existing alt text")
    # check_user_desc? returns false when description is present, so can_generate_alt? should be false
    expect(instance.can_generate_alt?).to be false
  end
end
