#!/usr/bin/env bash
# tests/host-drivers/github.test.sh — GitHub driver unit tests
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/mock-cli.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

OLD_PATH="$PATH"

source "$REPO_ROOT/scripts/host-drivers/github.sh"

# Test: host_name returns "github"
actual=$(host_name)
assert_eq "github" "$actual" "host_name"

echo "github.test.sh: host_name PASSED"
