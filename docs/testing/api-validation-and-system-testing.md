# API Validation and System Testing

This repository includes API verification for consolidated gem routes and a
combined Postman collection.

## 1) Verify route/controller/doc sync

```bash
ruby script/api/verify_routes_and_docs.rb
# or
bundle exec rake api:verify
```

This checks:

- every expected route has a matching controller action
- every route appears in the combined Postman collection under `docs/`
- every Postman entry maps to a real route

## 2) Run the combined Postman collection with Newman

```bash
BASE_URL=http://localhost:3000 \
ACCESS_TOKEN=... \
bash script/api/run_newman_suite.sh

# or
BASE_URL=http://localhost:3000 ACCESS_TOKEN=... bundle exec rake api:postman
```

The runner does a setup step first (`script/api/postman_setup.rb`) to generate
`tmp/newman.generated.env.json`, including dynamic IDs such as:

- `account_id`
- `username`
- `drafted_status_id` (if draft creation succeeds)
- `relay_id` (if relay creation succeeds)

You can disable auto setup and use a custom environment file:

```bash
AUTO_SETUP=0 POSTMAN_ENV_FILE=script/api/newman.env.staging.template.json \
bash script/api/run_newman_suite.sh
```

Templates for local and staging are available in `script/api/`.

## 3) Run request-spec smoke layer

```bash
bash script/api/run_rspec_smoke.sh
# or
bundle exec rake api:smoke
```

## 4) Run complete check sequence

```bash
BASE_URL=http://localhost:3000 ACCESS_TOKEN=... bundle exec rake api:full_check
```
