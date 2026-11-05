#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "fileutils"

ROOT_DIR = File.expand_path("../..", __dir__)
DOCS_DIR = File.join(ROOT_DIR, "docs")
COMBINED_LIST = File.join(DOCS_DIR, "newsmast-api-list.md")
COMBINED_COLLECTION = File.join(DOCS_DIR, "newsmast-api.postman_collection.json")
VERIFY_SCRIPT = File.join(ROOT_DIR, "script", "api", "verify_routes_and_docs.rb")

list_sources = Dir.glob(File.join(DOCS_DIR, "*-api-list.md")).sort.reject do |path|
  File.basename(path) == File.basename(COMBINED_LIST)
end

collection_sources = Dir.glob(File.join(DOCS_DIR, "*.postman_collection.json")).sort.reject do |path|
  File.basename(path) == File.basename(COMBINED_COLLECTION)
end

def normalize_path(path)
  path.gsub(/:[a-zA-Z_][a-zA-Z0-9_]*/) { |match| "{{#{match.delete_prefix(':')}}}" }
end

def request_body_for(path)
  case path
  when "/api/v1/custom_passwords"
    { email: "user@example.com" }
  when "/api/v1/custom_passwords/verify_otp"
    { id: "{{custom_password_id}}", otp_secret: "123456", email: "user@example.com" }
  when "/api/v1/custom_passwords/change_password"
    { current_password: "old-password", password: "new-password", password_confirmation: "new-password" }
  when "/api/v1/custom_passwords/change_email"
    { current_password: "password", email: "updated@example.com" }
  when "/api/v1/notification_tokens"
    { notification_token: "device-token", platform_type: "{{platform_type}}", mute: false }
  when "/api/v1/notification_tokens/revoke_token"
    { notification_token: "device-token" }
  when "/api/v1/notification_tokens/update_mute"
    { mute: true }
  when "/api/v1/user_locales"
    { lang: "en" }
  when "/api/v1/patchwork/alttext_settings/alttext"
    { enabled: true }
  when "/api/v1/patchwork/email_settings/notification"
    { allowed: true }
  when "/api/v1/delete_account"
    { password: "password" }
  when "/api/v1/patchwork/conversations/read_all"
    { target_account_id: "{{target_account_id}}" }
  when "/api/v1/custom_statuses/add_custom_boost_bot_status"
    { status_url: "https://example.social/@user/123", client_id: "{{client_id}}", client_secret: "{{client_secret}}" }
  when "/api/v1/custom_statuses/remove_custom_boost_bot_status"
    { status_id: "{{status_id}}", client_id: "{{client_id}}", client_secret: "{{client_secret}}" }
  when "/api/v1/drafted_statuses"
    { status: "Draft via Newman", drafted: true, visibility: "public" }
  when "/api/v1/patchwork/relays"
    { inbox_url: "{{relay_inbox_url}}" }
  end
end

def query_for(path)
  case path
  when "/api/v1/custom_passwords/request_otp"
    [ { "key" => "id", "value" => "token-or-reset-token" }, { "key" => "email", "value" => "user@example.com" } ]
  when "/api/v1/patchwork/conversations/check_conversation"
    [
      { "key" => "target_account_id", "value" => "{{target_account_id}}" },
      { "key" => "max_id", "value" => "{{max_id}}" },
      { "key" => "since_id", "value" => "{{since_id}}" },
      { "key" => "min_id", "value" => "{{min_id}}" }
    ]
  when "/api/v1/timelines/@{{username}}/feed"
    [
      { "key" => "local", "value" => "true" },
      { "key" => "remote", "value" => "false" },
      { "key" => "only_media", "value" => "false" },
      { "key" => "limit", "value" => "20" },
      { "key" => "max_id", "value" => "{{max_id}}" },
      { "key" => "since_id", "value" => "{{since_id}}" },
      { "key" => "min_id", "value" => "{{min_id}}" }
    ]
  when "/api/v1/timelines/for_you_custom_timeline"
    [
      { "key" => "grouped_admin_statuses", "value" => "true" },
      { "key" => "exclude_direct_statuses", "value" => "false" },
      { "key" => "exclude_replies", "value" => "false" },
      { "key" => "limit", "value" => "20" },
      { "key" => "max_id", "value" => "{{max_id}}" },
      { "key" => "since_id", "value" => "{{since_id}}" },
      { "key" => "min_id", "value" => "{{min_id}}" }
    ]
  when "/api/v1/utilities/link_preview"
    [ { "key" => "url", "value" => "{{link_preview_url}}" } ]
  else
    []
  end
end

def vars_for_collection
  {
    "base_url" => "http://localhost:3000",
    "access_token" => "",
    "custom_password_id" => "",
    "platform_type" => "ios",
    "account_id" => "",
    "target_account_id" => "",
    "max_id" => "",
    "since_id" => "",
    "min_id" => "",
    "username" => "",
    "client_id" => "",
    "client_secret" => "",
    "status_id" => "",
    "drafted_status_id" => "",
    "link_preview_url" => "https://example.com",
    "relay_id" => "",
    "relay_inbox_url" => "https://relay.example.com/inbox"
  }.map { |key, value| { "key" => key, "value" => value } }
end

def build_from_routes
  src = File.read(VERIFY_SCRIPT)
  match = src.match(/ROUTES\s*=\s*\[(.*?)\]\s*\.freeze/m)
  raise "Unable to parse ROUTES from #{VERIFY_SCRIPT}" unless match

  routes = eval("[#{match[1]}]", binding, VERIFY_SCRIPT)
  list = +"# Newsmast Mastodon API List\n\n"
  list << "Generated from route definitions in script/api/verify_routes_and_docs.rb.\n\n"
  list << "| Method | Path | Controller#Action |\n"
  list << "|---|---|---|\n"

  items = routes.map do |verb, path, controller, action|
    normalized_path = normalize_path(path)
    query = query_for(normalized_path)
    raw = "{{base_url}}#{normalized_path}"
    raw = "#{raw}?#{query.map { |pair| "#{pair['key']}=#{pair['value']}" }.join('&')}" unless query.empty?

    req = {
      "method" => verb,
      "header" => [],
      "url" => {
        "raw" => raw,
        "host" => [ "{{base_url}}" ],
        "path" => normalized_path.split("/").reject(&:empty?)
      },
      "description" => "Controller: #{controller}##{action}"
    }
    req["url"]["query"] = query unless query.empty?

    body = request_body_for(path)
    if body
      req["header"] << { "key" => "Content-Type", "value" => "application/json" }
      req["body"] = {
        "mode" => "raw",
        "raw" => JSON.pretty_generate(body),
        "options" => { "raw" => { "language" => "json" } }
      }
    end

    list << "| #{verb} | #{path} | #{controller}##{action} |\n"
    {
      "name" => "#{verb} #{path}",
      "request" => req,
      "response" => []
    }
  end

  collection = {
    "info" => {
      "_postman_id" => "newsmast-mastodon-combined",
      "name" => "Newsmast Mastodon Combined API",
      "description" => "Combined Postman collection generated from route definitions.",
      "schema" => "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
    },
    "auth" => {
      "type" => "bearer",
      "bearer" => [
        { "key" => "token", "value" => "{{access_token}}", "type" => "string" }
      ]
    },
    "variable" => vars_for_collection,
    "item" => items
  }

  FileUtils.mkdir_p(DOCS_DIR)
  File.write(COMBINED_LIST, list)
  File.write(COMBINED_COLLECTION, JSON.pretty_generate(collection))

  puts "Wrote #{COMBINED_LIST}"
  puts "Wrote #{COMBINED_COLLECTION}"
end

if list_sources.empty? || collection_sources.empty?
  build_from_routes
  exit 0
end

section_title = lambda do |path|
  File.basename(path, ".md").sub(/-api-list\z/, "").tr("_", " ").split("-").flat_map { |part| part.split(" ") }.map(&:capitalize).join(" ")
end

combined_markdown = +"# Newsmast Mastodon API List\n\n"
combined_markdown << "This file combines the API inventory from the merged engine surfaces.\n\n"
combined_markdown << "Included sections: #{list_sources.map { |path| section_title.call(path) }.join(', ')}\n\n"

list_sources.each do |path|
  content = File.read(path).sub(/\A# .*?\n+/, "").strip
  combined_markdown << "## #{section_title.call(path)}\n\n"
  combined_markdown << content
  combined_markdown << "\n\n"
end

variable_index = {}
collection_items = []
collection_auth = nil
collection_schema = "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"

collection_sources.each do |path|
  payload = JSON.parse(File.read(path))
  info = payload.fetch("info", {})
  name = info["name"] || File.basename(path, ".postman_collection.json")
  description = info["description"]
  collection_schema = info["schema"] if info["schema"]
  collection_auth ||= payload["auth"]

  Array(payload["variable"]).each do |entry|
    key = entry["key"]
    next if key.to_s.empty?
    variable_index[key] ||= entry
  end

  collection_items << {
    "name" => name,
    "description" => description,
    "item" => Array(payload["item"])
  }
end

combined_collection = {
  "info" => {
    "_postman_id" => "newsmast-mastodon-combined",
    "name" => "Newsmast Mastodon Combined API",
    "description" => "Combined Postman collection for accounts, conversations, custom feeds, local only posts, posts, and related endpoints.",
    "schema" => collection_schema
  },
  "auth" => collection_auth || {
    "type" => "bearer",
    "bearer" => [
      {
        "key" => "token",
        "value" => "{{access_token}}",
        "type" => "string"
      }
    ]
  },
  "variable" => variable_index.values.sort_by { |entry| entry["key"] },
  "item" => collection_items
}

FileUtils.mkdir_p(DOCS_DIR)
File.write(COMBINED_LIST, combined_markdown)
File.write(COMBINED_COLLECTION, JSON.pretty_generate(combined_collection))

puts "Wrote #{COMBINED_LIST}"
puts "Wrote #{COMBINED_COLLECTION}"
