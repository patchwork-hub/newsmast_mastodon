# frozen_string_literal: true

module NewsmastMastodon
  # Reads CUSTOM_RELAY_DOMAINS from ENV and provides helpers used across the
  # relay timeline feature.
  #
  # ENV format (comma-separated domains):
  #   CUSTOM_RELAY_DOMAINS=mastodon.social,mastodon.beer
  module CustomRelayConfig
    RELAY_SERVICE_BASE_URL = 'https://relay.fedi.buzz/instance'.freeze

    # Returns the list of configured relay domains.
    #
    # @return [Array<String>]
    def self.domains
      raw = ENV.fetch('CUSTOM_RELAY_DOMAINS', '')
      raw.split(',').map { |value| value.to_s.strip.downcase }.reject(&:blank?).uniq
    end

    # Builds the inbox URL for the #FediBuzz relay instance endpoint.
    #
    # Example:
    #   domain = "mastodon.social"
    #   inbox  = "https://relay.fedi.buzz/instance/mastodon.social"
    #
    # @param domain [String]
    # @return [String]
    def self.inbox_url_for(domain)
      "#{RELAY_SERVICE_BASE_URL}/#{domain.to_s.strip.downcase}"
    end

    # Extracts the configured source domain from a relay inbox URL.
    #
    # Supports both:
    # - https://relay.fedi.buzz/instance/<domain>
    # - legacy fallback host extraction for older URLs
    #
    # @param inbox_url [String]
    # @return [String, nil]
    def self.domain_from_inbox_url(inbox_url)
      path = URI.parse(inbox_url).path
      match = path.match(%r{\A/instance/([^/]+)\z})

      return match[1].downcase if match

      URI.parse(inbox_url).host&.downcase
    rescue URI::InvalidURIError
      nil
    end

    # Sanitizes a domain name into a Redis-safe string.
    # e.g. "mastodon.social" => "mastodon-social"
    #
    # @param domain [String]
    # @return [String]
    def self.sanitize_domain(domain)
      domain.gsub(/[^a-zA-Z0-9\-]/, '-').downcase
    end
  end
end
