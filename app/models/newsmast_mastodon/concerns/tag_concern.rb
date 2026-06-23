# frozen_string_literal: true

# Prepended into Tag class to override matching_name / find_or_create_by_names with listable-ban handling.
module NewsmastMastodon
  module Concerns
    module TagConcern
      extend ActiveSupport::Concern

      def self.prepended(base)
        base.singleton_class.class_eval do
          def matching_name(name_or_names, consider_ban_case = true)
            names = Array(name_or_names).map { |name| arel_table.lower(normalize(name)) }

            scope =
              if names.size == 1
                where(arel_table[:name].lower.eq(names.first))
              else
                where(arel_table[:name].lower.in(names))
              end

            scope = scope.listable if consider_ban_case
            scope
          end

          def find_or_create_by_names(name_or_names)
            names = Array(name_or_names).map { |str| [ normalize(str), str ] }.uniq(&:first)

            names.map do |(normalized_name, display_name)|
              tag = matching_name(normalized_name, false).first || create(
                name: normalized_name,
                display_name: display_name.gsub(Tag::HASHTAG_INVALID_CHARS_RE, "")
              )
              yield tag if block_given?
              tag
            end
          end
        end
      end
    end
  end
end
