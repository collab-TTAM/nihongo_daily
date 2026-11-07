#!/usr/bin/env bash
set -euo pipefail
# Requires an empty, disposable PostgreSQL database owned by the migration role.
: "${TEST_DATABASE_URL:?Set TEST_DATABASE_URL to an empty disposable PostgreSQL database}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
psql "$TEST_DATABASE_URL" -X -v ON_ERROR_STOP=1 -f "$repo_root/supabase/tests/bootstrap.sql"
for migration in "$repo_root"/supabase/migrations/*.sql; do
  psql "$TEST_DATABASE_URL" -X -v ON_ERROR_STOP=1 -f "$migration"
done
psql "$TEST_DATABASE_URL" -X -v ON_ERROR_STOP=1 -f "$repo_root/supabase/tests/baseline.sql"
python3 "$repo_root/scripts/test_review_concurrency.py"

psql "$TEST_DATABASE_URL" -X -v ON_ERROR_STOP=1 -f "$repo_root/supabase/tests/ai_receipts.sql"
python3 "$repo_root/scripts/test_ai_claim_concurrency.py"

psql "$TEST_DATABASE_URL" -X -v ON_ERROR_STOP=1 -f "$repo_root/supabase/tests/review_rpc.sql"
python3 "$repo_root/scripts/verify_review_parity.py"
python3 "$repo_root/scripts/test_submit_review_concurrency.py"
python3 "$repo_root/scripts/export_review_queue.py" "$repo_root/build/review-queue-sql.json"
