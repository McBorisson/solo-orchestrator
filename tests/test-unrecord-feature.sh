#!/usr/bin/env bash
# tests/test-unrecord-feature.sh — unit tests for _unrecord_feature_apply()
# Targets the pure state transform; interactive wrapper is manually verified.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Inline assertion helpers (zero-dependency; matches existing tests/*.sh pattern) ---

PASSED=0
FAILED=0

assert_eq() {
  local expected="$1" actual="$2" msg="${3:-}"
  if [ "$expected" != "$actual" ]; then
    echo "  ASSERT FAIL${msg:+ [$msg]}: expected '$expected', got '$actual'" >&2
    return 1
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "  ASSERT FAIL${msg:+ [$msg]}: '$haystack' does not contain '$needle'" >&2
    return 1
  fi
}

run_case() {
  local name="$1"
  shift
  if ( set -e; "$@" ); then
    echo "✓ $name"
    PASSED=$((PASSED + 1))
  else
    echo "✗ $name FAILED"
    FAILED=$((FAILED + 1))
  fi
}

seed_progress() {
  # Args: path, array-json, fslt, interval, testing_required, fslhc
  local path="$1" arr="$2" fslt="$3" interval="$4" testing="$5" fslhc="$6"
  cat > "$path" <<JSONEOF
{
  "features_completed": $arr,
  "features_since_last_test": $fslt,
  "test_interval": $interval,
  "last_test_session": null,
  "testing_required": $testing,
  "tester_count": 1,
  "bug_tracker": "github_issues",
  "sessions_completed": 0,
  "features_since_last_health_check": $fslhc
}
JSONEOF
}

# --- Source the script under test ---
# Task 1's source guard prevents dispatch from running.
source "$REPO_ROOT/scripts/test-gate.sh"

# --- Test cases ---

case_1_happy_path() {
  local work
  work=$(mktemp -d)
  trap "rm -rf '$work'" RETURN
  (
    cd "$work"
    mkdir -p .claude
    seed_progress .claude/build-progress.json '["foo"]' 1 2 false 1
    _unrecord_feature_apply "foo"
    assert_eq "[]" "$(jq -c '.features_completed' .claude/build-progress.json)" "array empty"
    assert_eq "0" "$(jq -r '.features_since_last_test' .claude/build-progress.json)" "fslt 0"
    assert_eq "0" "$(jq -r '.features_since_last_health_check' .claude/build-progress.json)" "fslhc 0"
    assert_eq "false" "$(jq -r '.testing_required' .claude/build-progress.json)" "testing_required false"
  )
}

case_2_duplicates_first_match() {
  local work
  work=$(mktemp -d)
  trap "rm -rf '$work'" RETURN
  (
    cd "$work"
    mkdir -p .claude
    seed_progress .claude/build-progress.json '["foo","bar","foo"]' 3 2 true 3
    _unrecord_feature_apply "foo"
    assert_eq '["bar","foo"]' "$(jq -c '.features_completed' .claude/build-progress.json)" "first 'foo' removed, second preserved"
  )
}

case_3_counter_floor_at_zero() {
  local work
  work=$(mktemp -d)
  trap "rm -rf '$work'" RETURN
  (
    cd "$work"
    mkdir -p .claude
    seed_progress .claude/build-progress.json '["foo"]' 0 2 false 0
    _unrecord_feature_apply "foo"
    assert_eq "0" "$(jq -r '.features_since_last_test' .claude/build-progress.json)" "fslt stays 0"
    assert_eq "0" "$(jq -r '.features_since_last_health_check' .claude/build-progress.json)" "fslhc stays 0"
  )
}

case_4_testing_required_flips_false() {
  local work
  work=$(mktemp -d)
  trap "rm -rf '$work'" RETURN
  (
    cd "$work"
    mkdir -p .claude
    seed_progress .claude/build-progress.json '["foo","bar"]' 2 2 true 2
    _unrecord_feature_apply "foo"
    assert_eq "1" "$(jq -r '.features_since_last_test' .claude/build-progress.json)" "fslt 1"
    assert_eq "false" "$(jq -r '.testing_required' .claude/build-progress.json)" "testing_required now false"
  )
}

case_5_testing_required_stays_true() {
  local work
  work=$(mktemp -d)
  trap "rm -rf '$work'" RETURN
  (
    cd "$work"
    mkdir -p .claude
    seed_progress .claude/build-progress.json '["foo","bar","baz"]' 3 2 true 3
    _unrecord_feature_apply "foo"
    assert_eq "2" "$(jq -r '.features_since_last_test' .claude/build-progress.json)" "fslt 2"
    assert_eq "true" "$(jq -r '.testing_required' .claude/build-progress.json)" "testing_required stays true"
  )
}

# --- Run all cases and report ---
echo "═══ test-unrecord-feature.sh ═══"
run_case "case 1: happy path"                     case_1_happy_path
run_case "case 2: duplicates → first match"       case_2_duplicates_first_match
run_case "case 3: counter floor at 0"             case_3_counter_floor_at_zero
run_case "case 4: testing_required flips false"   case_4_testing_required_flips_false
run_case "case 5: testing_required stays true"    case_5_testing_required_stays_true

echo ""
echo "═══════════════════════════════════════════"
echo "Tests: $PASSED passed, $FAILED failed"
echo "═══════════════════════════════════════════"
[ "$FAILED" -eq 0 ]
