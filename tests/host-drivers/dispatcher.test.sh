#!/usr/bin/env bash
# tests/host-drivers/dispatcher.test.sh — unit tests for scripts/lib/host.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/mock-cli.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Test 1: dispatcher reads host from manifest
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
mkdir -p .claude
echo '{"host":"github","mode":"personal","remote_url":"https://github.com/u/r"}' > .claude/manifest.json

source "$REPO_ROOT/scripts/lib/host.sh"

actual=$(host_read_from_manifest)
assert_eq "github" "$actual" "dispatcher reads host field"

echo "dispatcher.test.sh: read_from_manifest PASSED"

# Test 2: missing manifest returns error
WORK2=$(mktemp -d)
(
  cd "$WORK2"
  # No .claude directory
  set +e
  output=$(source "$REPO_ROOT/scripts/lib/host.sh" && host_read_from_manifest 2>&1)
  code=$?
  set -e
  assert_exit_code 1 "$code" "missing manifest returns code 1"
  assert_contains "$output" "manifest.json not found" "error message"
)
rm -rf "$WORK2"

# Test 3: malformed manifest (missing host field)
WORK3=$(mktemp -d)
(
  cd "$WORK3"
  mkdir -p .claude
  echo '{"mode":"personal"}' > .claude/manifest.json
  set +e
  output=$(source "$REPO_ROOT/scripts/lib/host.sh" && host_read_from_manifest 2>&1)
  code=$?
  set -e
  assert_exit_code 2 "$code" "missing host field returns code 2"
  assert_contains "$output" "--backfill-host" "remediation hint"
)
rm -rf "$WORK3"

echo "dispatcher.test.sh: all tests PASSED"
