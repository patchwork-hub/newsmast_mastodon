#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

ROOT = File.expand_path("../..", __dir__)

ROUTES = [
  [ "POST", "/api/v1/custom_passwords", "custom_passwords", "create" ],
  [ "PATCH", "/api/v1/custom_passwords/:id", "custom_passwords", "update" ],
  [ "PUT", "/api/v1/custom_passwords/:id", "custom_passwords", "update" ],
  [ "POST", "/api/v1/custom_passwords/verify_otp", "custom_passwords", "verify_otp" ],
  [ "GET", "/api/v1/custom_passwords/request_otp", "custom_passwords", "request_otp" ],
  [ "POST", "/api/v1/custom_passwords/change_password", "custom_passwords", "change_password" ],
  [ "POST", "/api/v1/custom_passwords/change_email", "custom_passwords", "change_email" ],
  [ "POST", "/api/v1/custom_passwords/bristol_cable_sign_in", "custom_passwords", "bristol_cable_sign_in" ],
  [ "POST", "/api/v1/notification_tokens", "notification_tokens", "create" ],
  [ "POST", "/api/v1/notification_tokens/revoke_token", "notification_tokens", "revoke_notification_token" ],
  [ "POST", "/api/v1/notification_tokens/update_mute", "notification_tokens", "update_mute" ],
  [ "GET", "/api/v1/notification_tokens/get_mute_status", "notification_tokens", "get_mute_status" ],
  [ "DELETE", "/api/v1/notification_tokens/reset_device_tokens/:platform_type", "notification_tokens", "reset_device_tokens" ],
  [ "POST", "/api/v1/user_locales", "user_locales", "create" ],
  [ "GET", "/api/v1/channels/starter_packs_channels", "channels", "starter_packs_channels" ],
  [ "GET", "/api/v1/channels/:id/starter_packs_detail", "channels", "starter_packs_detail" ],
  [ "GET", "/api/v1/patchwork/alttext_settings", "patchwork/alttext_settings", "index" ],
  [ "POST", "/api/v1/patchwork/alttext_settings/alttext", "patchwork/alttext_settings", "change_alttext_setting" ],
  [ "GET", "/api/v1/patchwork/email_settings", "patchwork/email_settings", "index" ],
  [ "POST", "/api/v1/patchwork/email_settings/notification", "patchwork/email_settings", "email_notification" ],
  [ "DELETE", "/api/v1/patchwork/account_deletion/:id", "patchwork/account_deletion", "destroy" ],
  [ "GET", "/api/v1/patchwork/conversations/check_conversation", "patchwork/conversations", "check_conversation" ],
  [ "POST", "/api/v1/patchwork/conversations/read_all", "patchwork/conversations", "read_all" ],
  [ "POST", "/api/v1/delete_account", "accounts", "delete_account" ],
  [ "GET", "/api/v1/accounts/leicester_notification", "accounts/patchwork_settings", "leicester_news_notification" ],
  [ "POST", "/api/v1/accounts/leicester_notification", "accounts/patchwork_settings", "update_leicester_news_notification" ],
  [ "POST", "/api/v1/accounts/subscribe_leicester", "accounts/ghost_subscriptions", "manage_subscription" ],
  [ "GET", "/api/v1/accounts/article_notifications", "accounts/patchwork_settings", "article_notifications" ],
  [ "POST", "/api/v1/accounts/article_notifications", "accounts/patchwork_settings", "update_article_notifications" ],
  [ "GET", "/api/v1/timelines/@:username/feed", "timelines/feeds", "show" ],
  [ "GET", "/api/v1/timelines/for_you_custom_timeline", "timelines/for_you_custom_timeline", "show" ],
  [ "POST", "/api/v1/custom_statuses/add_custom_boost_bot_status", "custom_statuses/custom_boost_bot_status", "add_custom_boost_bot_status" ],
  [ "POST", "/api/v1/custom_statuses/remove_custom_boost_bot_status", "custom_statuses/custom_boost_bot_status", "remove_custom_boost_bot_status" ],
  [ "GET", "/api/v1/local_only_posts/getLocalOnlySetting", "local_only_posts", "getLocalOnlySetting" ],
  [ "POST", "/api/v1/drafted_statuses", "drafted_statuses", "create" ],
  [ "GET", "/api/v1/drafted_statuses", "drafted_statuses", "index" ],
  [ "GET", "/api/v1/drafted_statuses/:id", "drafted_statuses", "show" ],
  [ "PATCH", "/api/v1/drafted_statuses/:id", "drafted_statuses", "update" ],
  [ "PUT", "/api/v1/drafted_statuses/:id", "drafted_statuses", "update" ],
  [ "DELETE", "/api/v1/drafted_statuses/:id", "drafted_statuses", "destroy" ],
  [ "POST", "/api/v1/drafted_statuses/:id/publish", "drafted_statuses", "publish" ],
  [ "GET", "/api/v1/utilities/link_preview", "utilities", "link_preview" ],
  [ "POST", "/api/v1/patchwork/relays", "relays", "create" ],
  [ "DELETE", "/api/v1/patchwork/relays/:id", "relays", "destroy" ],
  [ "POST", "/api/v1/ghost_webhooks", "webhooks", "handle_ghost" ],
  [ "POST", "/api/v1/wordpress_webhooks", "webhooks", "handle_wordpress" ]
].freeze

ID_VAR_NAMES = %w[
  custom_password_id drafted_status_id relay_id account_id channel_id
].freeze

def controller_file_for(controller)
  File.join(ROOT, "app/controllers/newsmast_mastodon/api/v1/#{controller}_controller.rb")
end

def controller_method_defined?(controller, action)
  file = controller_file_for(controller)
  return false unless File.exist?(file)

  src = File.read(file)
  src.match?(/^\s*def\s+#{Regexp.escape(action)}\b/)
end

def controller_presence_failures
  ROUTES.filter_map do |verb, path, controller, action|
    next if controller_method_defined?(controller, action)

    "#{verb} #{path} => #{controller}##{action} (missing file or action method)"
  end
end

def walk_items(items, acc = [])
  items.each do |item|
    request = item["request"]
    if request
      method = request["method"].to_s.upcase
      raw = request.dig("url", "raw")
      acc << [ method, normalize_raw_url(raw) ] if method != "" && raw
    end
    walk_items(item["item"], acc) if item["item"].is_a?(Array)
  end
  acc
end

def normalize_raw_url(raw)
  path = raw.sub(%r{^\{\{base_url\}\}}, "")
  path = path.split("?", 2).first
  path = "/#{path}" unless path.start_with?("/")
  path = path.gsub(%r!\{\{([^}]+)\}\}!) { |m| normalize_var($1, m) }
  path.gsub(%r{/+}, "/")
end

def normalize_var(var_name, original)
  return ":username" if var_name == "username"
  return ":platform_type" if var_name == "platform_type"
  return ":id" if var_name == "id"
  return ":id" if ID_VAR_NAMES.include?(var_name)

  original
end

def collection_routes
  combined_file = File.join(ROOT, "docs", "newsmast-api.postman_collection.json")
  files = if File.exist?(combined_file)
    [ combined_file ]
  else
    Dir.glob(File.join(ROOT, "docs/*.postman_collection.json")).sort
  end

  files.each_with_object([]) do |file, acc|
    json = JSON.parse(File.read(file))
    items = json["item"]
    next unless items.is_a?(Array)

    walk_items(items, acc)
  end
end

def format_route(route)
  "#{route[0]} #{route[1]}"
end

controller_failures = controller_presence_failures
route_set = ROUTES.map { |verb, path, _controller, _action| [ verb, path ] }.uniq
collection_set = collection_routes.uniq

missing_from_docs = route_set - collection_set
extra_in_docs = collection_set - route_set

puts "Route/controller/doc audit summary"
puts "- Routes expected: #{route_set.length}"
puts "- Routes in Postman collections: #{collection_set.length}"
puts "- Missing controller/action implementations: #{controller_failures.length}"
puts "- Routes missing from Postman docs: #{missing_from_docs.length}"
puts "- Extra routes in Postman docs: #{extra_in_docs.length}"
puts

if controller_failures.any?
  puts "Missing controller methods:"
  controller_failures.each { |line| puts "  - #{line}" }
  puts
end

if missing_from_docs.any?
  puts "Routes missing from Postman collections:"
  missing_from_docs.sort.each { |r| puts "  - #{format_route(r)}" }
  puts
end

if extra_in_docs.any?
  puts "Extra Postman entries not found in routes:"
  extra_in_docs.sort.each { |r| puts "  - #{format_route(r)}" }
  puts
end

if controller_failures.empty? && missing_from_docs.empty? && extra_in_docs.empty?
  puts "PASS: routes, controllers, and Postman collections are in sync."
  exit 0
end

puts "FAIL: route/controller/doc mismatches were found."
exit 1
