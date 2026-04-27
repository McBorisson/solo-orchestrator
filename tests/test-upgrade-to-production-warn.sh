#!/usr/bin/env bash
# tests/test-upgrade-to-production-warn.sh — T2-F regression test.
# Verifies that scripts/upgrade-project.sh --to-production emits a [WARN]
# line when the project's track is auto-bumped (e.g., light -> standard).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/upgrade-project.sh"

PASSED=0
FAILED=0
pass() { echo "  [PASS] $1"; PASSED=$((PASSED + 1)); }
fail_() { echo "  [FAIL] $1 — $2"; FAILED=$((FAILED + 1)); }

setup_project() {
  TMPDIR_T=$(mktemp -d)
  (
    cd "$TMPDIR_T"
    git init -q
    git remote add origin https://github.com/example/foo.git
    mkdir -p .claude
    cat > .claude/manifest.json <<'JSON'
{"frameworkVersion":"test","mode":"personal","host":"github"}
JSON
    cat > .claude/phase-state.json <<'JSON'
{"track":"light","deployment":"organizational","poc_mode":"private_poc","current_phase":1,"phases":{}}
JSON
    cat > .claude/tool-preferences.json <<'JSON'
{"context":{"track":"light","platform":"web","os":"darwin"},"preferences":{}}
JSON
    cat > .claude/intake-progress.json <<'JSON'
{"track":"light","deployment":"organizational"}
JSON
  )
}

teardown_project() { rm -rf "$TMPDIR_T"; }

t1_warn_emitted_on_track_bump_light_to_standard() {
  setup_project
  local out rc=0
  out=$(cd "$TMPDIR_T" && "$SCRIPT" --to-production </dev/null 2>&1) || rc=$?
  if ! echo "$out" | grep -qE '\[WARN\].*track.*(light|standard)'; then
    fail_ "T1" "expected [WARN] line about track bump (light->standard); rc=$rc out:\n$out"
    teardown_project
    return
  fi
  pass "T1: --to-production emits [WARN] when track auto-bumps light->standard"
  teardown_project
}

t2_no_warn_when_track_already_standard() {
  setup_project
  jq '.track = "standard"' "$TMPDIR_T/.claude/phase-state.json" > "$TMPDIR_T/.claude/phase-state.json.tmp" \
    && mv "$TMPDIR_T/.claude/phase-state.json.tmp" "$TMPDIR_T/.claude/phase-state.json"
  jq '.context.track = "standard"' "$TMPDIR_T/.claude/tool-preferences.json" > "$TMPDIR_T/.claude/tool-preferences.json.tmp" \
    && mv "$TMPDIR_T/.claude/tool-preferences.json.tmp" "$TMPDIR_T/.claude/tool-preferences.json"
  jq '.track = "standard"' "$TMPDIR_T/.claude/intake-progress.json" > "$TMPDIR_T/.claude/intake-progress.json.tmp" \
    && mv "$TMPDIR_T/.claude/intake-progress.json.tmp" "$TMPDIR_T/.claude/intake-progress.json"
  local out rc=0
  out=$(cd "$TMPDIR_T" && "$SCRIPT" --to-production </dev/null 2>&1) || rc=$?
  if echo "$out" | grep -qE '\[WARN\].*track.*bump'; then
    fail_ "T2" "should not emit track-bump [WARN] when already standard; out:\n$out"
    teardown_project
    return
  fi
  pass "T2: --to-production does NOT emit track-bump [WARN] when already standard"
  teardown_project
}

t3_help_documents_track_bump() {
  local out
  out=$("$SCRIPT" --help 2>&1)
  if ! echo "$out" | grep -qiE 'to-production.*(track|bump|light.*standard|auto)'; then
    fail_ "T3" "--help should mention track auto-bump for --to-production; got:\n$out"
    return
  fi
  pass "T3: --help mentions track auto-bump for --to-production"
}

echo "== tests/test-upgrade-to-production-warn.sh =="
t1_warn_emitted_on_track_bump_light_to_standard
t2_no_warn_when_track_already_standard
t3_help_documents_track_bump

echo ""
echo "== Total: $((PASSED + FAILED)) | Passed: $PASSED | Failed: $FAILED =="
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
