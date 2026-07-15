# Newsmast Mastodon API List

Generated from route definitions in script/api/verify_routes_and_docs.rb.

| Method | Path | Controller#Action |
|---|---|---|
| POST | /api/v1/custom_passwords | custom_passwords#create |
| PATCH | /api/v1/custom_passwords/:id | custom_passwords#update |
| PUT | /api/v1/custom_passwords/:id | custom_passwords#update |
| POST | /api/v1/custom_passwords/verify_otp | custom_passwords#verify_otp |
| GET | /api/v1/custom_passwords/request_otp | custom_passwords#request_otp |
| POST | /api/v1/custom_passwords/change_password | custom_passwords#change_password |
| POST | /api/v1/custom_passwords/change_email | custom_passwords#change_email |
| POST | /api/v1/custom_passwords/bristol_cable_sign_in | custom_passwords#bristol_cable_sign_in |
| POST | /api/v1/notification_tokens | notification_tokens#create |
| POST | /api/v1/notification_tokens/revoke_token | notification_tokens#revoke_notification_token |
| POST | /api/v1/notification_tokens/update_mute | notification_tokens#update_mute |
| GET | /api/v1/notification_tokens/get_mute_status | notification_tokens#get_mute_status |
| DELETE | /api/v1/notification_tokens/reset_device_tokens/:platform_type | notification_tokens#reset_device_tokens |
| POST | /api/v1/user_locales | user_locales#create |
| GET | /api/v1/channels/starter_packs_channels | channels#starter_packs_channels |
| GET | /api/v1/channels/:id/starter_packs_detail | channels#starter_packs_detail |
| GET | /api/v1/patchwork/alttext_settings | patchwork/alttext_settings#index |
| POST | /api/v1/patchwork/alttext_settings/alttext | patchwork/alttext_settings#change_alttext_setting |
| GET | /api/v1/patchwork/email_settings | patchwork/email_settings#index |
| POST | /api/v1/patchwork/email_settings/notification | patchwork/email_settings#email_notification |
| DELETE | /api/v1/patchwork/account_deletion/:id | patchwork/account_deletion#destroy |
| GET | /api/v1/patchwork/conversations/check_conversation | patchwork/conversations#check_conversation |
| POST | /api/v1/patchwork/conversations/read_all | patchwork/conversations#read_all |
| POST | /api/v1/delete_account | accounts#delete_account |
| GET | /api/v1/accounts/leicester_notification | accounts/patchwork_settings#leicester_news_notification |
| POST | /api/v1/accounts/leicester_notification | accounts/patchwork_settings#update_leicester_news_notification |
| POST | /api/v1/accounts/subscribe_leicester | accounts/ghost_subscriptions#manage_subscription |
| GET | /api/v1/accounts/article_notifications | accounts/patchwork_settings#article_notifications |
| POST | /api/v1/accounts/article_notifications | accounts/patchwork_settings#update_article_notifications |
| GET | /api/v1/timelines/@:username/feed | timelines/feeds#show |
| GET | /api/v1/timelines/for_you_custom_timeline | timelines/for_you_custom_timeline#show |
| GET | /api/v1/timelines/instances_timeline | timelines/instances_timeline#show |
| POST | /api/v1/custom_statuses/add_custom_boost_bot_status | custom_statuses/custom_boost_bot_status#add_custom_boost_bot_status |
| POST | /api/v1/custom_statuses/remove_custom_boost_bot_status | custom_statuses/custom_boost_bot_status#remove_custom_boost_bot_status |
| GET | /api/v1/local_only_posts/getLocalOnlySetting | local_only_posts#getLocalOnlySetting |
| POST | /api/v1/drafted_statuses | drafted_statuses#create |
| GET | /api/v1/drafted_statuses | drafted_statuses#index |
| GET | /api/v1/drafted_statuses/:id | drafted_statuses#show |
| PATCH | /api/v1/drafted_statuses/:id | drafted_statuses#update |
| PUT | /api/v1/drafted_statuses/:id | drafted_statuses#update |
| DELETE | /api/v1/drafted_statuses/:id | drafted_statuses#destroy |
| POST | /api/v1/drafted_statuses/:id/publish | drafted_statuses#publish |
| PATCH | /api/v1/patchwork/statuses/:status_id/reactions/:id | patchwork/status_reactions#update |
| PUT | /api/v1/patchwork/statuses/:status_id/reactions/:id | patchwork/status_reactions#update |
| DELETE | /api/v1/patchwork/statuses/:status_id/reactions/:id | patchwork/status_reactions#destroy |
| GET | /api/v1/utilities/link_preview | utilities#link_preview |
| POST | /api/v1/patchwork/relays | relays#create |
| DELETE | /api/v1/patchwork/relays/:id | relays#destroy |
| POST | /api/v1/ghost_webhooks | webhooks#handle_ghost |
| POST | /api/v1/wordpress_webhooks | webhooks#handle_wordpress |
