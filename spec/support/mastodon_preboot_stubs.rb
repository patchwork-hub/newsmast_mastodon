# frozen_string_literal: true

# Minimal Mastodon host stubs needed before the dummy app initializes.
# These must be available during eager load, but they must not shadow engine
# code that standalone specs are supposed to exercise.

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

unless defined?(ApplicationMailer)
  class ApplicationMailer < ActionMailer::Base; end
end

unless defined?(BaseService)
  class BaseService
    def call(*); end
  end
end

unless defined?(Redisable)
  module Redisable
    def redis; end
  end
end

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

unless defined?(DatabaseHelper)
  module DatabaseHelper
    def with_redis_tracking(*)
      yield if block_given?
    end
  end
end

unless defined?(RoutingHelper)
  module RoutingHelper; end
end

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

unless defined?(REST)
  module REST
    class MediaAttachmentSerializer < ActiveModel::Serializer; end
    class CredentialAccountSerializer < ActiveModel::Serializer; end
  end
end

unless ActiveRecord::Base.respond_to?(:has_attached_file)
  ActiveRecord::Base.define_singleton_method(:has_attached_file) { |*| }
  ActiveRecord::Base.define_singleton_method(:validates_attachment) { |*| }
  ActiveRecord::Base.define_singleton_method(:validates_attachment_content_type) { |*| }
  ActiveRecord::Base.define_singleton_method(:validates_attachment_size) { |*| }
end

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
