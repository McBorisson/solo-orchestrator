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

# Test: host_require_cli fails when gh missing
MOCK_DIR=$(mock_cli_setup)
# Isolated PATH — only MOCK_DIR, no system bins including gh
export PATH="$MOCK_DIR"
set +e
output=$(host_require_cli 2>&1)
code=$?
set -e
assert_exit_code 1 "$code" "missing gh returns 1"
assert_contains "$output" "gh" "mentions gh CLI"
assert_contains "$output" "install" "install guidance"
export PATH="$OLD_PATH"
mock_cli_teardown "$MOCK_DIR"
echo "github.test.sh: host_require_cli (missing) PASSED"

# Test: host_require_cli fails when gh present but not authed
MOCK_DIR=$(mock_cli_setup)
export PATH="$MOCK_DIR:$OLD_PATH"
mock_cli_respond gh "auth status" 1 "not logged in"
mock_cli_respond gh "--version" 0 "gh version 2.0"
set +e
output=$(host_require_cli 2>&1)
code=$?
set -e
assert_exit_code 2 "$code" "unauth'd gh returns 2"
assert_contains "$output" "authenticated" "mentions auth"
export PATH="$OLD_PATH"
mock_cli_teardown "$MOCK_DIR"
echo "github.test.sh: host_require_cli (unauthed) PASSED"

# Test: host_create_repo private
MOCK_DIR=$(mock_cli_setup)
export PATH="$MOCK_DIR:$OLD_PATH"
mock_cli_respond gh "repo create my-repo --private" 0 "https://github.com/user/my-repo"
url=$(host_create_repo "my-repo" "private")
assert_eq "https://github.com/user/my-repo" "$url" "create private repo returns URL"

# Test: host_create_repo public
mock_cli_respond gh "repo create pub-repo --public" 0 "https://github.com/user/pub-repo"
url=$(host_create_repo "pub-repo" "public")
assert_eq "https://github.com/user/pub-repo" "$url" "create public repo returns URL"

# Test: existing repo fails cleanly
mock_cli_respond gh "repo create dupe --private" 1 "repository already exists"
set +e
output=$(host_create_repo "dupe" "private" 2>&1)
code=$?
set -e
assert_exit_code 1 "$code" "existing repo returns non-zero"
assert_contains "$output" "already exists" "surfaces underlying error"

mock_cli_teardown "$MOCK_DIR"
export PATH="$OLD_PATH"
echo "github.test.sh: host_create_repo PASSED"

# Test: host_register_remote adds origin
WORK=$(mktemp -d); cd "$WORK"
git init -q
host_register_remote "https://github.com/u/r.git"
actual=$(git remote get-url origin)
assert_eq "https://github.com/u/r.git" "$actual" "register_remote sets origin"
cd - >/dev/null
rm -rf "$WORK"

# Test: host_register_remote replaces existing origin idempotently
WORK=$(mktemp -d); cd "$WORK"
git init -q
git remote add origin "https://example.com/old.git"
host_register_remote "https://github.com/u/r.git"
actual=$(git remote get-url origin)
assert_eq "https://github.com/u/r.git" "$actual" "register_remote replaces existing"
cd - >/dev/null
rm -rf "$WORK"

echo "github.test.sh: host_register_remote PASSED"
