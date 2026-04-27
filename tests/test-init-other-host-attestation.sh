#!/usr/bin/env bash
# tests/test-init-other-host-attestation.sh — BL-024 regression test.
#
# init.sh::create_and_protect_remote on the --git-host other path used to
# perform `git push` BEFORE the --branch-protection-attested attestation
# block. When the push failed (fake URL, corporate firewall, connectivity
# blip), `return 1` aborted the function and the attestation was silently
# dropped — even though the operator had explicitly passed
# --branch-protection-attested.
#
# The fix reorders the attestation block to run BEFORE push, since
# attestation is a forward-looking commitment by the operator and is
# independent of push success.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INIT_SH="$REPO_ROOT/init.sh"

PASSED=0
FAILED=0
pass() { echo "  [PASS] $1"; PASSED=$((PASSED + 1)); }
fail_() { echo "  [FAIL] $1 — $2"; FAILED=$((FAILED + 1)); }

# Run init.sh against a fake URL so push fails. With --branch-protection-attested,
# attestation must still be recorded despite the push failure.
t1_attestation_recorded_when_push_fails_to_fake_url() {
  local tmpdir; tmpdir=$(mktemp -d)
  local proj="$tmpdir/proj"
  local rc=0
  ( cd "$tmpdir" && "$INIT_SH" --non-interactive \
        --project bl024-trace \
        --platform web \
        --deployment personal \
        --language typescript \
        --project-dir "$proj" \
        --git-host other \
        --remote-url https://example.com/fake.git \
        --branch-protection-attested \
        --visibility private \
        --allow-existing-dir > "$tmpdir/out" 2>&1 ) || rc=$?

  # init.sh continues past push failure (BL-016/U-B fix), so it should exit 0.
  if [ "$rc" -ne 0 ]; then
    fail_ "T1" "expected init exit 0; rc=$rc tail:\n$(tail -10 "$tmpdir/out")"
    rm -rf "$tmpdir"; return
  fi

  # The push failure should still be visible in the log.
  if ! grep -q "Push failed" "$tmpdir/out"; then
    fail_ "T1" "expected to see 'Push failed' in output (this test relies on the fake URL failing); not present"
    rm -rf "$tmpdir"; return
  fi

  # The attestation MUST be recorded despite the push failure.
  if [ ! -f "$proj/.claude/process-state.json" ]; then
    fail_ "T1" "process-state.json missing"
    rm -rf "$tmpdir"; return
  fi
  local attested_by
  attested_by=$(jq -r '.phase2_init.attestations.branch_protection.attested_by // "MISSING"' "$proj/.claude/process-state.json")
  if [ "$attested_by" != "orchestrator" ]; then
    fail_ "T1" "expected attested_by=orchestrator; got '$attested_by'"
    rm -rf "$tmpdir"; return
  fi
  pass "T1: --branch-protection-attested recorded despite push-to-fake-URL failure"
  rm -rf "$tmpdir"
}

# Negative: without the attestation flag, push failure must NOT silently record an attestation.
t2_no_attestation_when_flag_absent() {
  local tmpdir; tmpdir=$(mktemp -d)
  local proj="$tmpdir/proj"
  # --git-host other REQUIRES --branch-protection-attested in non-interactive mode
  # (init.sh validates this and would exit 1 before reaching create_and_protect_remote).
  # So we test by checking that the attestation only appears when the flag was passed —
  # i.e., the recording is gated on the flag, not on push success.
  local rc=0
  ( cd "$tmpdir" && "$INIT_SH" --non-interactive \
        --project bl024-neg \
        --platform web \
        --deployment personal \
        --language typescript \
        --project-dir "$proj" \
        --git-host other \
        --remote-url https://example.com/fake.git \
        --visibility private \
        --allow-existing-dir > "$tmpdir/out" 2>&1 ) || rc=$?

  # Without --branch-protection-attested, init.sh should fail validation early.
  if [ "$rc" -eq 0 ]; then
    fail_ "T2" "expected init validation failure without --branch-protection-attested; got rc=0"
    rm -rf "$tmpdir"; return
  fi
  pass "T2: --git-host other without --branch-protection-attested fails validation (regression)"
  rm -rf "$tmpdir"
}

echo "== tests/test-init-other-host-attestation.sh =="
t1_attestation_recorded_when_push_fails_to_fake_url
t2_no_attestation_when_flag_absent

echo ""
echo "== Total: $((PASSED + FAILED)) | Passed: $PASSED | Failed: $FAILED =="
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
