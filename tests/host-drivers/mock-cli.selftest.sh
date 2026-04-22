#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/mock-cli.sh"

MOCK_DIR=$(mock_cli_setup)
trap 'mock_cli_teardown "$MOCK_DIR"' EXIT

export PATH="$MOCK_DIR:$PATH"

# Case: fixture hit
mock_cli_respond gh "repo create test-repo" 0 "https://github.com/u/test-repo"
output=$(gh repo create test-repo --private 2>&1)
assert_eq "https://github.com/u/test-repo" "$output" "fixture stdout"

# Case: fixture miss (no match)
set +e
gh wat-is-this 2>/dev/null
code=$?
set -e
assert_exit_code 127 "$code" "unregistered command exits 127"

echo "mock-cli self-test PASSED"
