# Development Testing and Local Services

This guide covers local development checks and how to run specs with optional
Docker-backed infrastructure.

## Quick checks

Run the default local checks from the gem directory:

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Standalone test run with Docker services

Use Docker only for infrastructure (PostgreSQL, Redis, Elasticsearch), while
running the Rails app and specs directly on your machine.

From your workspace root, start services:

```bash
docker compose up -d db redis es
```

From `newsmast_mastodon`, run specs against those services:

```bash
export DATABASE_HOST=127.0.0.1
export DATABASE_PORT=5432
export DATABASE_USER=postgres
export DATABASE_PASSWORD=postgres
export REDIS_HOST=127.0.0.1
export REDIS_PORT=6379
export ES_ENABLED=true
export ES_HOST=127.0.0.1
export ES_PORT=9200

bundle exec rspec --format progress
```

Optional cleanup:

```bash
docker compose down
```

## Notes

- `RAILS_ENV=test bin/rails app:db:prepare` can fail if duplicate migration
  names exist in the consolidated migration set.
- If that occurs, run specs directly as shown above until migration naming
  conflicts are resolved.
