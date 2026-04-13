#!/bin/bash
set -euo pipefail

SCRIPT="./logscan.sh"
PASS=0
FAIL=0

assert_equals() {
  local description="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "PASS: $description"
    ((++PASS))
  else
    echo "FAIL: $description"
    echo "  expected: '$expected'"
    echo "  actual:   '$actual'"
    ((++FAIL))
  fi
}

assert_contains() {
  local description="$1"
  local needle="$2"
  local haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "PASS: $description"
    ((++PASS))
  else
    echo "FAIL: $description"
    echo "  expected to contain: '$needle'"
    echo "  actual output: '$haystack'"
    ((++FAIL))
  fi
}

assert_not_contains() {
  local description="$1"
  local needle="$2"
  local haystack="$3"
  if ! echo "$haystack" | grep -qF "$needle"; then
    echo "PASS: $description"
    ((++PASS))
  else
    echo "FAIL: $description"
    echo "  expected NOT to contain: '$needle'"
    echo "  actual output: '$haystack'"
    ((++FAIL))
  fi
}

# ── Fixtures ──────────────────────────────────────────────────────────────────
TMPDIR=$(mktemp -d)

# Realistic app log with timestamps and mixed severity levels
APPLOG="$TMPDIR/app.log"
cat > "$APPLOG" <<'EOF'
2024-03-01 08:00:01 [INFO]  Application started successfully
2024-03-01 08:01:14 [INFO]  Connected to database
2024-03-01 08:04:37 [ERROR] Failed to fetch user profile: connection refused
2024-03-01 08:05:02 [WARN]  Retry attempt 1 of 3
2024-03-01 08:05:07 [ERROR] Failed to fetch user profile: connection refused
2024-03-01 08:05:12 [WARN]  Retry attempt 2 of 3
2024-03-01 08:05:17 [ERROR] Failed to fetch user profile: connection refused
2024-03-01 08:05:17 [ERROR] Max retries exceeded, giving up
2024-03-01 08:10:45 [INFO]  Health check passed
2024-03-01 08:22:11 [WARN]  Memory usage at 78%
2024-03-01 08:45:59 [ERROR] Disk write failed: no space left on device
EOF

# Clean log with no errors
CLEANLOG="$TMPDIR/clean.log"
cat > "$CLEANLOG" <<'EOF'
2024-03-01 09:00:00 [INFO]  Service started
2024-03-01 09:01:00 [INFO]  Health check passed
2024-03-01 09:02:00 [INFO]  Request processed successfully
EOF

# ── Output format ─────────────────────────────────────────────────────────────
output=$(bash $SCRIPT ERROR "$APPLOG")
assert_contains "output includes 'Summary:' header" "Summary:" "$output"
assert_contains "output includes 'Errors found:' line" "Errors found:" "$output"
assert_contains "output includes 'Search results:' header" "Search results:" "$output"

# ── ERROR level counting ──────────────────────────────────────────────────────
error_count=$(bash $SCRIPT '\[ERROR\]' "$APPLOG" | grep "^Errors found:" | awk '{print $NF}')
assert_equals "counts 5 [ERROR] entries" "5" "$error_count"

warn_count=$(bash $SCRIPT '\[WARN\]' "$APPLOG" | grep "^Errors found:" | awk '{print $NF}')
assert_equals "counts 3 [WARN] entries" "3" "$warn_count"

clean_count=$(bash $SCRIPT '\[ERROR\]' "$CLEANLOG" | grep "^Errors found:" | awk '{print $NF}')
assert_equals "reports 0 errors in clean log" "0" "$clean_count"

# ── ERROR entries appear in results ──────────────────────────────────────────
error_output=$(bash $SCRIPT '\[ERROR\]' "$APPLOG")
assert_contains "connection refused error appears" "Failed to fetch user profile: connection refused" "$error_output"
assert_contains "disk write error appears" "Disk write failed: no space left on device" "$error_output"
assert_contains "max retries error appears" "Max retries exceeded, giving up" "$error_output"

# ── Non-error entries excluded from ERROR scan ────────────────────────────────
assert_not_contains "INFO entries excluded from ERROR results" "[INFO]" "$error_output"
assert_not_contains "WARN entries excluded from ERROR results" "[WARN]" "$error_output"

# ── WARN entries appear when scanning for warnings ───────────────────────────
warn_output=$(bash $SCRIPT '\[WARN\]' "$APPLOG")
assert_contains "memory warning appears" "Memory usage at 78%" "$warn_output"
assert_contains "retry warning appears" "Retry attempt 1 of 3" "$warn_output"
assert_not_contains "ERROR entries excluded from WARN results" "[ERROR]" "$warn_output"

# ── Specific error message scan ───────────────────────────────────────────────
retry_count=$(bash $SCRIPT "connection refused" "$APPLOG" | grep "^Errors found:" | awk '{print $NF}')
assert_equals "counts 3 'connection refused' entries" "3" "$retry_count"

# Cleanup
rm -rf "$TMPDIR"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
