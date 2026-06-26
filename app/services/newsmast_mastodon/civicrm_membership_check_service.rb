# frozen_string_literal: true

require 'httparty'
require 'json'
require 'uri'

module NewsmastMastodon
  class CivicrmMembershipCheckService
    include HTTParty

    ALLOWED_GROUP_IDS = [3, 12, 13].freeze
    CONTACT_GET_PATH = '/civicrm/ajax/api4/Contact/get'

    Result = Struct.new(:valid?, :error_message, keyword_init: true)

    def initialize(email)
      @email = email
    end

    def call
      return valid_result unless feature_enabled?
      return invalid_result if @email.blank?
      return valid_result if allowlisted_email?
      return invalid_result unless config_present?

      response = self.class.get(endpoint_url, headers: request_headers, query: { params: request_params.to_json })
      unless response.success?
        Rails.logger.error("CiviCRM membership check unauthorized/failed: status=#{response.code} body=#{response.body}")
        return invalid_result
      end

      body = response.parsed_response
      return valid_result if body.is_a?(Hash) && body['count'].to_i.positive?
      return valid_result if body.is_a?(Hash) && body['values'].is_a?(Array) && body['values'].any?

      invalid_result
    rescue StandardError => e
      Rails.logger.error("CiviCRM membership check failed: #{e.class} #{e.message}")
      invalid_result
    end

    private

    def feature_enabled?
      ActiveModel::Type::Boolean.new.cast(ENV.fetch('CSID_MEMBERSHIP_CHECK_ENABLED', 'false'))
    end

    def config_present?
      base_url.present? && auth_token.present?
    end

    def base_url
      raw = ENV.fetch('CIVICRM_BASE_URL', nil).to_s.strip
      return '' if raw.blank?

      candidate = raw.match?(%r{\Ahttps?://}i) ? raw : "https://#{raw}"
      uri = URI.parse(candidate)

      # Guard against values such as http://host:443 by enforcing HTTPS for port 443.
      uri.scheme = 'https' if uri.port == 443 || uri.scheme.blank?
      uri.to_s.chomp('/')
    rescue URI::InvalidURIError
      ''
    end

    def auth_token
      ENV.fetch('CIVICRM_AUTH_TOKEN', nil).to_s.strip.gsub(/\A'+|'+\z/, '')
    end

    def endpoint_url
      "#{base_url}#{CONTACT_GET_PATH}"
    end

    def request_headers
      {
        'accept' => 'application/json, text/plain, */*',
        'x-civi-auth' => formatted_auth_token,
        'x-requested-with' => 'XMLHttpRequest',
        'skipinterceptor' => 'true'
      }
    end

    def formatted_auth_token
      return auth_token if auth_token.match?(/\ABearer\s+/i)

      "Bearer #{auth_token}"
    end

    def request_params
      {
        select: ['id', 'email.email'],
        join: [['Email AS email', 'LEFT', ['email.is_primary', '=', true]]],
        where: [
          ['is_deleted', '=', false],
          ['email.email', '=', @email],
          ['groups', 'IN', ALLOWED_GROUP_IDS]
        ],
        limit: 1
      }
    end

    def allowlisted_email?
      allowlisted_emails.include?(@email.to_s.strip.downcase)
    end

    def allowlisted_emails
      allowed_mails = ENV.fetch('CSID_MEMBERSHIP_ALLOWLIST_EMAILS', nil).to_s.strip
      return [] if allowed_mails.blank?

      parsed_emails = parse_allowlisted_emails(allowed_mails)
      parsed_emails
        .map { |email| email.to_s.strip.downcase }
        .reject(&:blank?)
        .uniq
    end

    def parse_allowlisted_emails(raw_value)
      return JSON.parse(raw_value) if raw_value.start_with?('[')

      raw_value.split(/\s*,\s*/)
    rescue JSON::ParserError
      raw_value.split(/\s*,\s*/)
    end

    def valid_result
      Result.new(valid?: true, error_message: nil)
    end

    def invalid_result
      Result.new(valid?: false, error_message: I18n.t('api.account.errors.membership_not_eligible'))
    end
  end
end