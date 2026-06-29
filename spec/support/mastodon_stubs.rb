# frozen_string_literal: true

# Stub definitions for Mastodon host-provided constants.
#
# The engine relies on many constants from the Mastodon host application that
# are NOT available in the minimal dummy Rails app used for unit testing.
# Defining stubs here lets spec files load (and discover pending examples via
# `require_host!`) without triggering Zeitwerk autoload failures.
#
# These stubs are intentionally minimal — they only supply enough structure for
# the engine files to be required without error.  Real behaviour is tested via
# the host-app integration harness.

# ---------------------------------------------------------------------------
# External gem stubs (not pulled into the test bundle)
# ---------------------------------------------------------------------------
unless defined?(Chewy)
  module Chewy
    class Index
      def self.index_name(*); end
      def self.index_scope(*); end
      def self.field(*); end
      def self.root(*); end
    end
  end
end

# Sidekiq – workers `include Sidekiq::Worker`, but the minimal dummy app does
# not boot Sidekiq. Require the real gem (present in the gem's dev bundle) so
# `sidekiq_options` etc. resolve; fall back to a minimal stub if unavailable.
unless defined?(Sidekiq::Worker)
  begin
    require "sidekiq"
  rescue LoadError
    module Sidekiq
      module Worker
        def self.included(base) = base.extend(ClassMethods)

        module ClassMethods
          def sidekiq_options(*); end
          def perform_async(*); end
        end
      end
    end
  end
end

# ---------------------------------------------------------------------------
# Mastodon application-level stubs
# ---------------------------------------------------------------------------

# ApplicationMailer – base class for all Mastodon mailers
unless defined?(ApplicationMailer)
  class ApplicationMailer < ActionMailer::Base; end
end

# BaseService – base class for Mastodon service objects
unless defined?(BaseService)
  class BaseService
    def call(*); end
  end
end

# Redisable – mixed into Mastodon models / services for Redis helpers
unless defined?(Redisable)
  module Redisable
    def redis; end
  end
end

# Paginable – pagination concern used by Mastodon models
unless defined?(Paginable)
  module Paginable
    def self.included(base)
      base.extend(ClassMethods)
    end
    module ClassMethods
      def paginate_by_id(*); end
      def paginate_by_max_id(*); end
    end
  end
end

# DatabaseHelper – utility concern used in some Mastodon workers
unless defined?(DatabaseHelper)
  module DatabaseHelper
    def with_redis_tracking(*); yield if block_given?; end
  end
end

# RoutingHelper – Rails routing helpers mixed into Mastodon services
unless defined?(RoutingHelper)
  module RoutingHelper; end
end

# ActiveModel::Serializer – provided by active_model_serializers gem
unless defined?(ActiveModel::Serializer)
  module ActiveModel
    class Serializer
      def self.attribute(*); end
      def self.attributes(*); end
      def self.belongs_to(*); end
      def self.has_many(*); end
      def self.has_one(*); end
    end
  end
end

# REST namespace and serializers used by engine serializers
unless defined?(REST)
  module REST
    class MediaAttachmentSerializer < ActiveModel::Serializer; end
    class CredentialAccountSerializer < ActiveModel::Serializer; end
  end
end

# Paperclip's has_attached_file – mixed into ActiveRecord::Base by Mastodon
unless ActiveRecord::Base.respond_to?(:has_attached_file)
  ActiveRecord::Base.define_singleton_method(:has_attached_file) { |*| }
  ActiveRecord::Base.define_singleton_method(:validates_attachment) { |*| }
  ActiveRecord::Base.define_singleton_method(:validates_attachment_content_type) { |*| }
  ActiveRecord::Base.define_singleton_method(:validates_attachment_size) { |*| }
end

# ---------------------------------------------------------------------------
# Optional feature constants referenced by the engine
# ---------------------------------------------------------------------------

unless defined?(LocalOnlyPosts)
  module LocalOnlyPosts
    module StatusSerializerExtension; end
  end
end

unless defined?(LongPost)
  module LongPost
    module InstanceSerializerExtension; end
    module StatusLengthValidatorPatch; end
    class DraftedStatusSerializer; end
  end
end

# ---------------------------------------------------------------------------
# Engine constants that live outside the NewsmastMastodon namespace
# (top-level helpers / mailers defined by this engine)
# ---------------------------------------------------------------------------

require File.expand_path("../../app/helpers/brand_color_helper", __dir__) unless defined?(::BrandColorHelper)
require File.expand_path("../../app/helpers/non_channel_helper", __dir__) unless defined?(::NonChannelHelper)
require File.expand_path("../../app/helpers/patchwork_helper", __dir__) unless defined?(::PatchworkHelper)
unless defined?(MASTODON_ROOT)
  require File.expand_path("../../app/mailers/custom_passwords_mailer", __dir__) unless defined?(::CustomPasswordsMailer)
end

# Overrides::CredentialAccountSerializer lives outside NewsmastMastodon
unless defined?(Overrides)
  module Overrides
    module CredentialAccountSerializer; end
  end
end

# Expose the top-level stubs inside the NewsmastMastodon engine namespace so
# that specs describing e.g. `NewsmastMastodon::BrandColorHelper` resolve.
module NewsmastMastodon
  BrandColorHelper              = ::BrandColorHelper              unless const_defined?(:BrandColorHelper, false)
  NonChannelHelper              = ::NonChannelHelper              unless const_defined?(:NonChannelHelper, false)
  PatchworkHelper               = ::PatchworkHelper               unless const_defined?(:PatchworkHelper, false)
  LocalOnlyPosts                = ::LocalOnlyPosts                unless const_defined?(:LocalOnlyPosts, false)
  LongPost                      = ::LongPost                      unless const_defined?(:LongPost, false)
  if defined?(::CustomPasswordsMailer)
    CustomPasswordsMailer       = ::CustomPasswordsMailer         unless const_defined?(:CustomPasswordsMailer, false)
  end

  module Overrides
    CredentialAccountSerializer = ::Overrides::CredentialAccountSerializer unless const_defined?(:CredentialAccountSerializer, false)
  end
end
