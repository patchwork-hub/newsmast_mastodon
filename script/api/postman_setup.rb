#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "time"
require "fileutils"

BASE_URL = ENV.fetch("BASE_URL", "http://localhost:3000").chomp("/")
ACCESS_TOKEN = ENV.fetch("ACCESS_TOKEN", "")
PLATFORM_TYPE = ENV.fetch("PLATFORM_TYPE", "ios")
LINK_PREVIEW_URL = ENV.fetch("LINK_PREVIEW_URL", "https://example.com")
RELAY_INBOX_URL = ENV.fetch("RELAY_INBOX_URL", "https://relay.example.com/inbox")

OUT_PATH = ENV.fetch("POSTMAN_ENV_OUTPUT_FILE", File.expand_path("../../tmp/newman.generated.env.json", __dir__))

if ACCESS_TOKEN.empty?
  warn "ACCESS_TOKEN is required. Export ACCESS_TOKEN before running postman setup."
  exit 1
end

def request(method, path, body: nil, query: nil, auth: true)
  uri = URI.parse("#{BASE_URL}#{path}")
  if query && !query.empty?
    uri.query = URI.encode_www_form(query)
  end

  klass = Net::HTTP.const_get(method.capitalize)
  req = klass.new(uri)
  req["Accept"] = "application/json"
  req["Content-Type"] = "application/json"
  req["Authorization"] = "Bearer #{ACCESS_TOKEN}" if auth
  req.body = JSON.generate(body) if body

  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(req)
  end
end

def parse_json(response)
  JSON.parse(response.body)
rescue JSON::ParserError
  {}
end

def dig_id(payload, *paths)
  paths.each do |path|
    keys = path.is_a?(Array) ? path : [ path ]
    value = keys.reduce(payload) { |acc, key| acc.is_a?(Hash) ? acc[key] : nil }
    return value if value && value.to_s != ""
  end
  nil
end

def log(status, label)
  puts "[#{status}] #{label}"
end

def fetch_verify_credentials
  response = request("get", "/api/v1/accounts/verify_credentials")
  unless response.code.to_i == 200
    raise "verify_credentials failed with HTTP #{response.code}: #{response.body}"
  end

  payload = parse_json(response)
  account_id = dig_id(payload, "id")
  username = payload["username"].to_s
  raise "verify_credentials response missing id" if account_id.nil?
  raise "verify_credentials response missing username" if username.empty?

  log("200", "Fetched verify_credentials")
  [ account_id.to_s, username ]
end

def create_drafted_status
  body = {
    status: "API smoke draft #{Time.now.utc.iso8601}",
    drafted: true,
    visibility: "public",
    language: "en"
  }
  response = request("post", "/api/v1/drafted_statuses", body: body)
  return "" unless [ 200, 201 ].include?(response.code.to_i)

  payload = parse_json(response)
  id = dig_id(payload, "id")
  id ||= dig_id(payload, "data", "id")
  log("#{response.code}", "Created drafted status")
  id.to_s
end

def create_relay
  response = request("post", "/api/v1/patchwork/relays", body: { inbox_url: RELAY_INBOX_URL })
  return "" unless [ 200, 201 ].include?(response.code.to_i)

  payload = parse_json(response)
  id = dig_id(payload, "id")
  id ||= dig_id(payload, "data", "id")
  log("#{response.code}", "Created relay")
  id.to_s
end

account_id, username = fetch_verify_credentials

drafted_status_id = create_drafted_status
relay_id = create_relay

vars = {
  "base_url" => BASE_URL,
  "access_token" => ACCESS_TOKEN,
  "custom_password_id" => "",
  "platform_type" => PLATFORM_TYPE,
  "account_id" => account_id,
  "target_account_id" => account_id,
  "max_id" => "",
  "since_id" => "",
  "min_id" => "",
  "username" => username,
  "client_id" => "",
  "client_secret" => "",
  "status_id" => "",
  "drafted_status_id" => drafted_status_id,
  "link_preview_url" => LINK_PREVIEW_URL,
  "relay_id" => relay_id,
  "relay_inbox_url" => RELAY_INBOX_URL
}

json = {
  id: "newsmast-mastodon-generated",
  name: "Newsmast API Generated Environment",
  values: vars.map { |key, value| { key: key, value: value.to_s, enabled: true } }
}

FileUtils.mkdir_p(File.dirname(OUT_PATH))
File.write(OUT_PATH, JSON.pretty_generate(json))
puts "Wrote #{OUT_PATH}"
