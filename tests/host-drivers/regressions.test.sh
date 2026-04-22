#!/usr/bin/env bash
# tests/host-drivers/regressions.test.sh — regression cases for host-aware repo gate.
# Covers: lancache-pattern (no remote at Phase 1→2), manifest missing host field,
# protection drift (API returns force-push enabled).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/mock-cli.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OLD_PATH="$PATH"

# Test 1: Lancache-pattern — project at current_phase=2 with no remote
# should fail the backstop gate check.
WORK=$(mktemp -d); cd "$WORK"
git init -q
mkdir -p .claude
echo '{"host":"github","mode":"personal","remote_url":""}' > .claude/manifest.json
cat > .claude/phase-state.json <<PJ
{"current_phase": 2, "gates": {"phase_0_to_1": "2026-04-22", "phase_1_to_2": "2026-04-22"}}
PJ
touch APPROVAL_LOG.md
# No remote configured → host_verify_protection will fail early
set +e
output=$(bash "$REPO_ROOT/scripts/check-phase-gate.sh" 2>&1)
code=$?
set -e
# Expected: backstop fails → increments issues → non-zero exit
# (Other gate checks may also contribute to failures; we specifically look for the backstop message)
assert_contains "$output" "backstop" "lancache pattern triggers backstop message"
cd - >/dev/null; rm -rf "$WORK"
echo "regressions.test.sh: lancache-pattern PASSED"

# Test 2: Manifest missing host field — dispatcher should report with remediation hint
WORK=$(mktemp -d); cd "$WORK"
git init -q
mkdir -p .claude
echo '{"mode":"personal"}' > .claude/manifest.json  # no host field
source "$REPO_ROOT/scripts/lib/host.sh"
set +e
output=$(host_read_from_manifest 2>&1)
code=$?
set -e
assert_exit_code 2 "$code" "missing host returns code 2"
assert_contains "$output" "--backfill-host" "remediation hint"
cd - >/dev/null; rm -rf "$WORK"
echo "regressions.test.sh: manifest-missing-host PASSED"

# Test 3: Protection drift — mock API returns force-push enabled; verify_protection fails
MOCK_DIR=$(mock_cli_setup); export PATH="$MOCK_DIR:$OLD_PATH"
WORK=$(mktemp -d); cd "$WORK"
git init -q
git remote add origin "https://github.com/u/r.git"
mkdir -p .claude
echo '{"host":"github","mode":"personal"}' > .claude/manifest.json
mock_cli_respond gh "api repos/u/r/branches/main/protection" 0 '{"enforce_admins":{"enabled":true},"allow_force_pushes":{"enabled":true}}'
source "$REPO_ROOT/scripts/host-drivers/github.sh"
set +e
output=$(host_verify_protection "main" "personal" 2>&1)
code=$?
set -e
assert_exit_code 1 "$code" "drift returns non-zero"
assert_contains "$output" "force-push" "drift message mentions specific rule"
cd - >/dev/null; rm -rf "$WORK"
mock_cli_teardown "$MOCK_DIR"; export PATH="$OLD_PATH"
echo "regressions.test.sh: protection-drift PASSED"

echo "regressions.test.sh: all tests PASSED"
