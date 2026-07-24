# newsmast-mastodon
The Newsmast Mastodon gem extends a Mastodon server to provide functionality for content filters, posts management, account management, content channels and more. The gem interacts with the Newsmast Apps for Change mobile apps - customised mobile apps for Newsmast Communities, and the Newsmast Dashboard, which allows extended customisation of Mastodon server features and settings.

## Versioning
This project uses compatibility-first versioning: `X.Y.Z.N`.

- `X.Y.Z` tracks the target Mastodon version.
- `N` is the gem patch level for that exact Mastodon line.

Examples:

- `4.5.11` is for Mastodon `4.5.11`.
- `4.5.11.0` is the first gem release for Mastodon `4.5.11`.
- `4.5.11.1` is a gem-only patch release, still for Mastodon `4.5.11`.
- `4.6.3` is for Mastodon `4.6.3`.
- `4.6.3.0` is the first gem release for Mastodon `4.6.3`.
- `4.6.4.0` starts support for the next Mastodon compatibility line.

## Prerequisites
The plugin requires Ruby `>= 3.3.0, < 4.1.0`, a matching Mastodon service version, and (depending on intended use) may also require [Newsmast Dashboard](https://github.com/TheNewsmastFoundation/newsmast-dashboard).

## Installation
See [https://github.com/TheNewsmastFoundation/documentation/tree/main/newsmast-mastodon](https://github.com/TheNewsmastFoundation/documentation/tree/main/newsmast-mastodon)

## How the gem overrides Mastodon

The gem is a standard Rails engine. It changes Mastodon behavior at runtime by:

- prepending modules into Mastodon services, serializers, validators, and
  controllers (see `config/initializers/prepend_concerns.rb`);
- including model concerns into `Account`, `Status`, `User`, and other host
  models;
- replacing Mastodon's core Chewy search indexes (`AccountsIndex`,
  `StatusesIndex`, `PublicStatusesIndex`) with its own namespaced definitions
  while preserving the upstream Elasticsearch index names;
- shipping additional migrations, frontend components, and API controllers that
  mount onto the host.

This lets any Mastodon host install the gem and receive the same behavior that
was previously maintained as inline fork patches.

## Documentation
See [https://github.com/TheNewsmastFoundation/documentation/blob/main/newsmast-mastodon/configuration.md](https://github.com/TheNewsmastFoundation/documentation/blob/main/newsmast-mastodon/configuration.md)

## Contributing

Our governance policies and contributor guides are located in our main documentation repo:

* [Contributing to Newsmast](https://github.com/TheNewsmastFoundation/documentation/blob/main/CONTRIBUTING.md)
* [Governance](https://github.com/TheNewsmastFoundation/documentation/blob/main/GOVERNANCE.md)
* [Security Policy](https://github.com/TheNewsmastFoundation/documentation/blob/main/SECURITY.md)
* [Code of Conduct](https://github.com/TheNewsmastFoundation/documentation/blob/main/CODE_OF_CONDUCT.md)
