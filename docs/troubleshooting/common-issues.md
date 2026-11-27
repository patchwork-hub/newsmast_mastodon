# Troubleshooting

## Missing newsmast_mastodon tables or columns

Errors such as `relation "server_settings" does not exist` or
`unknown attribute 'alttext_enabled' for User` mean the gem's migrations are
recorded as run but never ran. Older versions of the gem had this problem when
the database was created from Mastodon's `db/schema.rb` (`db:setup`,
`db:prepare`, `db:schema:load` or `mastodon:setup`) instead of `db:migrate`.

Upgrade the gem, then re-run its migrations. They only create what is missing:

```bash
RAILS_ENV=production bin/rails newsmast_mastodon:repair_migrations
```

## Commit fails with GPG signing error

If commit signing is enabled but GPG is not configured correctly, commits can
fail with errors such as `failed to write commit object`.

Use one of the following:

```bash
git commit --no-gpg-sign -m "<message>"
# or disable signing for this repository
git config commit.gpgsign false
```

## Host-integration workflow warnings in editors

Some editors warn about unknown workflow inputs or context keys in
`.github/workflows/ci.yml` for optional host-integration jobs. This is expected
when host-related values are not configured locally.

For manual host integration runs, provide the workflow dispatch inputs defined
in `.github/workflows/ci.yml`.

## `bundle exec rake api:verify` route/doc mismatch on `{{id}}`

If Postman paths use `{{id}}`, route verification should normalize that to
`:id`. Ensure the verifier includes normalization for both explicit id aliases
and bare `id` placeholders.
