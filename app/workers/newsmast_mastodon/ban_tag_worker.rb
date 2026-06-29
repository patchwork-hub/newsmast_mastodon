# frozen_string_literal: true


module NewsmastMastodon
  class BanTagWorker
    include Sidekiq::Worker

    def perform
      start_time = Time.current
      Rails.logger.info "Starting to check tags against keyword filters at #{start_time}..."

      begin
        # Get all keyword filters of type hashtag or both
        keyword_filters = NewsmastMastodon::KeywordFilter.where(filter_type: [ :hashtag, :both ])
        # Community filters scoped to global (patchwork_community_id: nil) and filter_out
        community_keyword_filters = NewsmastMastodon::CommunityFilterKeyword.where(patchwork_community_id: nil, is_filter_hashtag: true, filter_type: "filter_out")

        if keyword_filters.empty? && community_keyword_filters.empty?
          Rails.logger.info "No hashtag or both type keyword filters found. Exiting."
          return
        end

        Rails.logger.info "Found #{keyword_filters.count} keyword filters and #{community_keyword_filters.count} community keyword filters to check against"

        combined_keywords = keyword_filters.pluck(:keyword) + community_keyword_filters.pluck(:keyword)

        filter_keywords = Set.new(combined_keywords.compact.map { |k| k.to_s.downcase.gsub("#", "").strip })

        banned_count = 0
        error_count = 0
        processed_count = 0

        total_tags = Tag.count
        Rails.logger.info "Checking #{total_tags} tags..."

        Tag.select(:id, :name, :display_name, :listable, :trendable).find_each do |tag|
          processed_count += 1

          begin
            next if tag.listable == false && tag.trendable == false

            tag_matched = false

            tag_name_lower = tag.name.downcase.strip
            if filter_keywords.include?(tag_name_lower)
              tag_matched = true
            elsif filter_keywords.any? { |keyword| tag_name_lower.include?(keyword) }
              tag_matched = true
            end

            if !tag_matched && tag.respond_to?(:display_name) && tag.display_name.present?
              display_name_lower = tag.display_name.downcase.strip
              if filter_keywords.include?(display_name_lower)
                tag_matched = true
              elsif filter_keywords.any? { |keyword| display_name_lower.include?(keyword) }
                tag_matched = true
              end
            end

            if tag_matched
              Rails.logger.info "Found tag to ban: '#{tag.name}' (ID: #{tag.id})"

              begin
                tag.update!(listable: false, trendable: false)

                tag.statuses.each do |status|
                  status.update!(
                    is_banned: true,
                    updated_at: Time.current
                  )

                  if status.local?
                    status.update!(
                      sensitive: true,
                      spoiler_text: "Sensitive content!!!"
                    )
                  end
                end

                banned_count += 1
              rescue => e
                error_count += 1
                Rails.logger.error "Error updating tag ID #{tag.id}: #{e.message}"
              end
            end
          rescue => e
            error_count += 1
            Rails.logger.error "Error processing tag ID #{tag.id}: #{e.message}"
            Rails.logger.error "Error in update_banned_tags for tag #{tag.id}: #{e.message}\n#{e.backtrace.join("\n")}"
          end

          if (processed_count % 1000).zero?
            Rails.logger.info "Processed #{processed_count}/#{total_tags} tags (#{(processed_count.to_f / total_tags * 100).round(2)}%)"
          end
        end

        end_time = Time.current
        duration = (end_time - start_time).round(2)

        Rails.logger.info "\n" + "=" * 50
        Rails.logger.info "SUMMARY:"
        Rails.logger.info "Total tags processed: #{processed_count}"
        Rails.logger.info "Tags updated to banned: #{banned_count}"
        Rails.logger.info "Errors encountered: #{error_count}"
        Rails.logger.info "Duration: #{duration} seconds"
        Rails.logger.info "Average: #{(processed_count.to_f / duration).round(2)} tags/second"
        Rails.logger.info "=" * 50
      rescue => e
        Rails.logger.error "Fatal error in update_banned_tags: #{e.message}"
        Rails.logger.error "Fatal error in update_banned_tags: #{e.message}\n#{e.backtrace.join("\n")}"
        raise
      end
    end
  end
end
