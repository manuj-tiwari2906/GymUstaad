#!/usr/bin/env bash
# Apply the Supabase stub, every migration and the seed to an EMPTY Postgres, then check
# that every public table has row-level security on.
# Usage: DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/postgres supabase/tests/check_migrations.sh
set -euo pipefail

: "${DATABASE_URL:?set DATABASE_URL to an empty Postgres database}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PSQL=(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -o /dev/null)

"${PSQL[@]}" -f "$ROOT/tests/supabase_stub.sql"
for f in "$ROOT"/migrations/*.sql; do
  echo "apply $(basename "$f")"
  "${PSQL[@]}" -f "$f"
done
echo "apply seed.sql"
"${PSQL[@]}" -f "$ROOT/seed.sql"

no_rls=$(psql "$DATABASE_URL" -At -c \
  "select string_agg(tablename, ', ') from pg_tables where schemaname = 'public' and not rowsecurity")
if [[ -n "$no_rls" ]]; then
  echo "FAIL: tables without row-level security: $no_rls"
  exit 1
fi
echo "OK: migrations + seed applied, RLS on every public table"
