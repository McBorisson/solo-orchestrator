#!/usr/bin/env bash
# tests/host-drivers/run-all.sh — run every host-driver test and aggregate results.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

total=0
failed=0

for t in "$SCRIPT_DIR"/*.test.sh "$SCRIPT_DIR"/*.selftest.sh; do
  [ -f "$t" ] || continue
  name=$(basename "$t")
  echo "─── $name ───"
  if bash "$t"; then
    total=$((total + 1))
  else
    failed=$((failed + 1))
    total=$((total + 1))
    echo "FAILED: $name"
  fi
  echo ""
done

echo "═══════════════════════════════════════════"
echo "Host-driver tests: $total run, $failed failed"
echo "═══════════════════════════════════════════"
[ "$failed" -eq 0 ]
