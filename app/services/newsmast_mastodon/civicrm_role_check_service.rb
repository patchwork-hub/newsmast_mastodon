# frozen_string_literal: true

require "httparty"
require "json"
require "uri"

module NewsmastMastodon
  class CivicrmRoleCheckService
    include HTTParty

    class TransientFailure < StandardError; end

    CONTACT_GET_PATH = "/civicrm/ajax/api4/Contact/get"
    RELATIONSHIP_GET_PATH = "/civicrm/ajax/api4/Relationship/get"
    GROUP_IDS_IN_PRIORITY_ORDER = [ 15, 16, 3 ].freeze

    # "Fellows" is not a CiviCRM group: membership is an active relationship
    # with the Fellows contact. FELLOWS_GROUP_ID is the Result#group_id used for it.
    FELLOWS_GROUP_ID = :fellows
    FELLOWS_CONTACT_ID = 992
    FELLOWS_DISPLAY_NAME = "Fellows"

    Result = Struct.new(:values, :group_id, :transient_error, keyword_init: true)

    def initialize(email, force_remote: false)
      @email = email
      @force_remote = force_remote
    end

    def call
      return empty_result unless force_remote? || feature_enabled?
      return empty_result if @email.blank? || !config_present?
      
      fellows_values = fetch_values(RELATIONSHIP_GET_PATH, fellows_request_params)
      return transient_failure_result if fellows_values.nil?

      fellows_values = fellows_values.select { |value| fellows_relationship?(value) }
      if fellows_values.any?
        return Result.new(values: fellows_values, group_id: FELLOWS_GROUP_ID, transient_error: false)
      end

      GROUP_IDS_IN_PRIORITY_ORDER.each do |group_id|
        values = fetch_values(CONTACT_GET_PATH, request_params(group_id))
        return transient_failure_result if values.nil?
        next if values.empty?

        return Result.new(values: values, group_id: group_id, transient_error: false)
      end

      empty_result
    rescue StandardError => e
      Rails.logger.error("CiviCRM role check failed: #{e.class}")
      transient_failure_result
    end

    private

    # Returns the response "values" array, or nil when the request failed.
    def fetch_values(path, params)
      response = self.class.get(
        "#{base_url}#{path}",
        headers: request_headers,
        query: { params: params.to_json }
      )
      response_body = response.respond_to?(:body) ? normalize_utf8(response.body) : ""

      unless response.success?
        Rails.logger.error("CiviCRM role check failed: status=#{response.code}")
        return nil
      end

      body = response.parsed_response
      body = parse_response_body(response_body) unless body.is_a?(Hash)
      response_values(body)
    end

    def fellows_relationship?(value)
      return false unless value.is_a?(Hash)

      value["contact_id_b"].to_s == FELLOWS_CONTACT_ID.to_s &&
        value["contact_id_b.display_name"] == FELLOWS_DISPLAY_NAME
    end

    def force_remote?
      @force_remote
    end

    def feature_enabled?
      ActiveModel::Type::Boolean.new.cast(ENV.fetch("CSID_ROLE_ASSIGNMENT_ENABLED", "false"))
    end

    def config_present?
      base_url.present? && auth_token.present?
    end

    def base_url
      raw = ENV.fetch("CIVICRM_BASE_URL", nil).to_s.strip
      return "" if raw.blank?

      candidate = raw.match?(%r{\Ahttps?://}i) ? raw : "https://#{raw}"
      uri = URI.parse(candidate)
      uri.scheme = "https" if uri.port == 443 || uri.scheme.blank?
      uri.to_s.chomp("/")
    rescue URI::InvalidURIError
      ""
    end

    def auth_token
      ENV.fetch("CIVICRM_AUTH_TOKEN", nil).to_s.strip.gsub(/\A'+|'+\z/, "")
    end

    def request_headers
      {
        "accept" => "application/json, text/plain, */*",
        "x-civi-auth" => formatted_auth_token,
        "x-requested-with" => "XMLHttpRequest",
        "skipinterceptor" => "true"
      }
    end

    def formatted_auth_token
      return auth_token if auth_token.match?(/\ABearer\s+/i)

      "Bearer #{auth_token}"
    end

    def request_params(group_id)
      {
        select: [ "id" ],
        join: [
          [ "Email AS email", "LEFT", [ "email.is_primary", "=", true ] ],
          [ "GroupContact AS group_contact", "LEFT", [ "group_contact.status", "=", "'Added'" ] ]
        ],
        groupBy: [ "id" ],
        where: [
          [ "is_deleted", "=", false ],
          [ "email.email", "=", @email ],
          [ "groups", "IN", [ group_id ] ]
        ]
      }
    end

    def fellows_request_params
      {
        select: [
          "id",
          "relationship_type_id",
          "contact_id_a",
          "contact_id_a.display_name",
          "contact_id_a.email_primary.email",
          "contact_id_b",
          "contact_id_b.display_name",
          "contact_id_b.email_primary.email"
        ],
        where: [
          [ "OR", [ [ "contact_id_a", "=", FELLOWS_CONTACT_ID ], [ "contact_id_b", "=", FELLOWS_CONTACT_ID ] ] ],
          [ "OR", [ [ "contact_id_a.email_primary.email", "=", @email ], [ "contact_id_b.email_primary.email", "=", @email ] ] ],
          [ "is_active", "=", true ]
        ]
      }
    end

    def parse_response_body(response_body)
      JSON.parse(response_body)
    rescue JSON::ParserError
      {}
    end

    def normalize_utf8(value)
      value
        .to_s
        .dup
        .force_encoding(Encoding::UTF_8)
        .scrub
    end

    def response_values(body)
      return [] unless body.is_a?(Hash)
      return [] unless body.key?("values") || body.key?(:values)

      values = body["values"] || body[:values]
      values.is_a?(Array) ? values : []
    end

    def empty_result
      Result.new(values: [], group_id: nil, transient_error: false)
    end

    def transient_failure_result
      Result.new(values: [], group_id: nil, transient_error: true)
    end
  end
end
