# Troubleshooting

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
