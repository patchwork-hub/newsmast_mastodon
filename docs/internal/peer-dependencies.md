# Peer dependencies

This engine is designed to be mounted inside a Mastodon host application
(Mastodon 4.5.11). Several runtime concerns are intentionally **not** declared as
runtime dependencies in `newsmast_mastodon.gemspec` because the host Mastodon
application already provides them. The engine expects the host application to
include these gems at the versions Mastodon 4.5.11 uses.

## Gems provided by the host Mastodon application

| Gem | Host Mastodon 4.5.11 version | Why it is a peer dependency |
|-----|------------------------------|----------------------------|
| `sidekiq` | `8.0.9` | Background workers rely on `Sidekiq::Worker`. Kept as a development dependency in the gemspec only for local engine testing. |
| `chewy` | `7.6.0` | Chewy indexes live under `app/chewy/newsmast_mastodon/` and the engine integrates with host Chewy configuration. |
| `doorkeeper` | `5.8.2` | The engine extends host Doorkeeper configuration (password grant flow). |
| `devise` | `5.0.4` | The engine references Devise authentication helpers and configuration. |

## Gems newly declared as engine runtime dependencies

The following gems are referenced directly in engine code and are now declared
as runtime dependencies in `newsmast_mastodon.gemspec`, pinned to the versions
used by Mastodon 4.5.11:

| Gem | Gemspec constraint | Host version | Direct usage in engine |
|-----|-------------------|--------------|------------------------|
| `jwt` | `~> 2.10.0` | `2.10.3` | Ghost webhook JWT signing |
| `faraday` | `~> 2.14.0` | `2.14.2` | `Faraday::ConnectionFailed` rescue in tag search |
| `parslet` | `~> 2.0.0` | `2.0.0` | `Parslet::ParseFailed` rescue in tag search |

## Version alignment policy

When updating this engine for a new Mastodon release, compare
`newsmast_mastodon.gemspec` against the host Mastodon `Gemfile.lock` and keep
runtime dependencies aligned with the host versions. Do not let the engine drift
ahead of the host (e.g., the engine previously resolved Rails to `8.1.3` while
the host Mastodon 4.5.11 uses `8.0.4.1`).

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
