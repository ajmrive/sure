---
name: running-sure-tests-safely
description: Use when about to run bin/rails test / rake test in the Sure repo, or when adding/changing features that touch config/database.yml, the compose*.yml files, POSTGRES_* env vars, or CI test config — anything that could let the test suite hit a non-test database and wipe real data.
---

# Running Sure tests safely

## Overview

The Rails test suite **truncates its database** on every run. In this repo the
Docker setup (`compose.dev.yml`) sets `POSTGRES_DB=sure_production`, and the dev
container runs against that real database. The hazard: if the `test` environment
also reads `POSTGRES_DB`, `bin/rails test` wipes real financial data.

**Core rule:** the test environment must ALWAYS resolve to a `*_test` database,
never to `sure_production` (or any non-test DB), no matter what `POSTGRES_DB` is.

## The two guardrails that must stay intact

1. **`config/database.yml` — the `test:` block must NOT read `POSTGRES_DB`.**
   It reads its own var:
   ```yaml
   test:
     <<: *default
     database: <%= ENV.fetch("POSTGRES_TEST_DB") { "sure_test" } %>
   ```
   If you ever see the `test:` block reading `POSTGRES_DB`, that is the bug —
   fix it back to `POSTGRES_TEST_DB`.

2. **PreToolUse(Bash) hook** `~/.claude/hooks/sure-guard-rails-test-db.sh`
   (wired in `.claude/settings.local.json`) blocks any `rails test` whose test
   DB does not contain `test`. Defense-in-depth; do not rely on it alone.

## Verify before running tests

Confirm the test env resolves to a test DB (must print `sure_test`):

```bash
docker exec sure-web-1 bash -lc \
  'RAILS_ENV=test bin/rails runner "print ActiveRecord::Base.connection_db_config.database"'
```

Then run tests normally — no `POSTGRES_DB` override needed:

```bash
docker exec sure-web-1 bin/rails test
```

## When adding a feature — re-check these

- Touched `config/database.yml`? Re-confirm `test:` still uses `POSTGRES_TEST_DB`.
- Touched `compose*.yml` / env / `.env`? Re-run the verify command above.
- Changed CI (`.github/workflows/ci.yml`)? CI uses `RAILS_ENV: test` + a test DB;
  keep it that way.
- **Always back up first** if anything DB-related changed: `pg_dump -Fc` to
  `~/sure-db-backups/` (outside the repo — it holds real financial data).

## Red flags — STOP

- About to run `POSTGRES_DB=… bin/rails test` or `RAILS_ENV=production … test`.
- The verify command prints `sure_production` (or anything without `test`).
- You're tempted to "just run the tests quickly" without verifying the DB.

All of these mean: do not run the suite. Fix `database.yml` first.
