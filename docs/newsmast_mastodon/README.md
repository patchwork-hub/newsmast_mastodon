# newsmast-mastodon

The `newsmast_mastodon` gem is a Rails engine that extends a Mastodon server for the Newsmast Apps for Change mobile apps and the Newsmast Dashboard. This documentation covers gem version `4.6.5.x`, which targets Mastodon `4.6.5`.

## Contents

- [Configuration](configuration.md): environment variables
- [Accounts](features.md#accounts): sign-up, password and email flows, notification tokens, settings, account deletion
- [Content filters](features.md#content-filters): keyword filters, spam filters, banned statuses, tags and accounts
- [Custom feeds](features.md#custom-feeds): channel feeds, For You timeline, instances timeline, relays
- [Posts](features.md#posts): drafts, long posts, local-only posts, reactions, link previews, boosting

Related reference material in this folder:

- [API list](../newsmast-api-list.md) and [Postman collection](../newsmast-api.postman_collection.json)
- [Environment variable reference](../configuration/environment-variables.md)
- [Troubleshooting](../troubleshooting/common-issues.md)

## Requirements

- Ruby `>= 3.3.0, < 4.1.0`
- A Mastodon host at the matching version (`4.6.5`)
- Optional: [Newsmast Dashboard](https://github.com/TheNewsmastFoundation/newsmast-dashboard), which manages server settings, filters and channels stored in the shared database

## Installation

1. Add the gem to the Mastodon host `Gemfile`:

   ```ruby
   gem "newsmast_mastodon", "~> 4.6.5"
   ```

2. Install and copy the engine migrations:

   ```bash
   bundle install
   bin/rails newsmast_mastodon:install:migrations
   bin/rails db:migrate
   ```

3. Set the environment variables you need (see [Configuration](configuration.md)) and restart web and Sidekiq processes.

The engine refuses to boot on a host that does not meet its installation checks (`NewsmastMastodon::InstallationGuard`).

## Updating

Gem versions follow `X.Y.Z.N`: `X.Y.Z` is the Mastodon version and `N` is the gem patch level. When you upgrade Mastodon, upgrade to the gem line with the same `X.Y.Z`, then re-run the install-migrations task and `db:migrate`. See the [CHANGELOG](../../CHANGELOG.md) for per-release notes.

## How the gem works

The gem changes Mastodon at runtime, with no fork patches:

- Modules are prepended into Mastodon services, serializers, validators and controllers (`config/initializers/prepend_concerns.rb`).
- Concerns are included into `Account`, `Status`, `User`, `Tag`, `Notification` and other host models.
- Extra API routes are mounted from `config/routes.rb` under `/api/v1`.
- Extra migrations add tables and columns such as `server_settings`, `patchwork_drafted_statuses`, `patchwork_notification_tokens`, `patchwork_status_reactions`, and `is_banned` / `local_only` flags.

Several features read settings that the Newsmast Dashboard writes to the shared database (`server_settings`, communities, keyword filters). Without the Dashboard, these features fall back to defaults.
