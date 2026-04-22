#!/usr/bin/env bash
# tests/host-drivers/bitbucket.test.sh — Bitbucket driver unit tests
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/mock-cli.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OLD_PATH="$PATH"

source "$REPO_ROOT/scripts/host-drivers/bitbucket.sh"

# host_name
assert_eq "bitbucket" "$(host_name)" "host_name"
echo "bitbucket.test.sh: host_name PASSED"

# host_require_cli — no creds
unset BITBUCKET_USER BITBUCKET_APP_PASSWORD
set +e; output=$(host_require_cli 2>&1); code=$?; set -e
assert_exit_code 1 "$code" "no creds fails"
assert_contains "$output" "BITBUCKET_USER" "mentions env var"

# with creds
export BITBUCKET_USER="testuser" BITBUCKET_APP_PASSWORD="testpass"
set +e; host_require_cli; code=$?; set -e
assert_exit_code 0 "$code" "with creds passes"
unset BITBUCKET_USER BITBUCKET_APP_PASSWORD
echo "bitbucket.test.sh: host_require_cli PASSED"

# host_register_remote
WORK=$(mktemp -d); cd "$WORK"
git init -q
host_register_remote "https://bitbucket.org/ws/repo.git"
assert_eq "https://bitbucket.org/ws/repo.git" "$(git remote get-url origin)" "register"
cd - >/dev/null; rm -rf "$WORK"
echo "bitbucket.test.sh: host_register_remote PASSED"

# _bb_parse_origin
WORK=$(mktemp -d); cd "$WORK"
git init -q
git remote add origin "https://bitbucket.org/ws/repo.git"
assert_eq "ws/repo" "$(_bb_parse_origin)" "parse_origin"
cd - >/dev/null; rm -rf "$WORK"
echo "bitbucket.test.sh: _bb_parse_origin PASSED"

echo "bitbucket.test.sh: all tests PASSED"
