# Peer dependencies

This engine is designed to be mounted inside a Mastodon host application
(Mastodon 4.6.3). Several runtime concerns are intentionally **not** declared as
runtime dependencies in `newsmast_mastodon.gemspec` because the host Mastodon
application already provides them. The engine expects the host application to
include these gems at the versions the current host Mastodon release uses.

## Gems provided by the host Mastodon application

| Gem | Host Mastodon 4.6.3 version | Why it is a peer dependency |
| --- | --- | --- |
| `sidekiq` | `8.1.6` | Background workers rely on `Sidekiq::Worker`. Kept as a development dependency in the gemspec only for local engine testing. |
| `chewy` | `8.4.1` | Chewy indexes live under `app/chewy/newsmast_mastodon/` and the engine integrates with host Chewy configuration. |
| `doorkeeper` | `5.9.2` | The engine extends host Doorkeeper configuration (password grant flow). |
| `devise` | `5.0.4` | The engine references Devise authentication helpers and configuration. |

## Gems newly declared as engine runtime dependencies

The following gems are referenced directly in engine code and are now declared
as runtime dependencies in `newsmast_mastodon.gemspec`, pinned to the versions
used by Mastodon 4.6.3:

| Gem | Gemspec constraint | Host version | Direct usage in engine |
| --- | --- | --- | --- |
| `jwt` | `~> 2.10.0` | `2.10.3` | Ghost webhook JWT signing |
| `faraday` | `~> 2.14.0` | `2.14.3` | `Faraday::ConnectionFailed` rescue in tag search |
| `parslet` | `~> 2.0.0` | `2.0.0` | `Parslet::ParseFailed` rescue in tag search |

## Chewy index overrides

The engine ships its own Chewy index definitions under
`app/chewy/newsmast_mastodon/` for the three core Mastodon indexes:

- `AccountsIndex` → `NewsmastMastodon::AccountsIndex`
- `StatusesIndex` → `NewsmastMastodon::StatusesIndex`
- `PublicStatusesIndex` → `NewsmastMastodon::PublicStatusesIndex`

At boot time, `config/initializers/prepend_concerns.rb` replaces the host's
constant with the engine's class. The engine classes declare an explicit
`index_name` so the Elasticsearch/OpenSearch index name stays identical to
vanilla Mastodon (e.g. `public_statuses_index`). This lets downstream hosts keep
Mastodon's upstream Chewy files untouched while the gem applies fork-specific
scope changes such as excluding banned accounts and statuses.

When upgrading, verify that the engine's Chewy files are still aligned with the
upstream host files and that the `index_name` values have not drifted.

## Version alignment policy

When updating this engine for a new Mastodon release, compare
`newsmast_mastodon.gemspec` against the host Mastodon `Gemfile.lock` and keep
runtime dependencies aligned with the host versions. Do not let the engine drift
ahead of the host's supported version ranges.

## Development-only tools

The gems below are used only for engine-local development and testing. They are
not provided by host Mastodon and are kept with their existing constraints:

- `factory_bot_rails`
- `vcr`
- `sqlite3`
- `rubocop-rails-omakase`

### Removed development tools

- `annotaterb` was removed from the gemspec. Schema annotation tooling is not
  used by the engine itself; contributors can rely on the host Mastodon
  application's own annotation setup if needed.
