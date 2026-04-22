#!/usr/bin/env bash
# tests/host-drivers/mock-cli.sh
# Shared harness for host-driver unit tests. Creates a temp dir with stub CLIs
# (gh, glab, curl) that echo canned fixtures and exit with canned codes.
# Usage:
#   source tests/host-drivers/mock-cli.sh
#   MOCK_DIR=$(mock_cli_setup)
#   export PATH="$MOCK_DIR:$PATH"
#   mock_cli_respond gh "repo create my-repo --private" 0 "https://github.com/user/my-repo"
#   # ... run code that invokes `gh repo create ...`
#   mock_cli_teardown "$MOCK_DIR"

set -euo pipefail

mock_cli_setup() {
  local dir
  dir=$(mktemp -d "${TMPDIR:-/tmp}/solo-mock-cli-XXXXXX")
  echo "$dir"
}

# Register a stub response for a command invocation.
# Args: cli_name arg_pattern exit_code stdout
mock_cli_respond() {
  local cli="$1" pattern="$2" code="$3" output="$4"
  local dir="${MOCK_DIR:?MOCK_DIR not set — call mock_cli_setup first}"
  local stub="$dir/$cli"
  mkdir -p "$dir/.fixtures"

  # Each stub writes its arg-line, consults fixtures, and exits.
  cat > "$stub" <<'STUB_EOF'
#!/usr/bin/env bash
fixture_dir="$(dirname "$0")/.fixtures"
cli="$(basename "$0")"
args="$*"
# Find first matching fixture file: <cli>.<hash-of-pattern>
for f in "$fixture_dir/$cli".*; do
  [ -f "$f" ] || continue
  pattern=$(head -n1 "$f")
  if [[ "$args" == *"$pattern"* ]]; then
    code=$(sed -n '2p' "$f")
    tail -n +3 "$f"
    exit "$code"
  fi
done
echo "mock-cli: no fixture for '$cli $args'" >&2
exit 127
STUB_EOF
  chmod +x "$stub"

  # Register the fixture
  local hash
  hash=$(echo -n "$pattern" | shasum -a 256 | cut -c1-8)
  {
    echo "$pattern"
    echo "$code"
    printf '%s' "$output"
  } > "$dir/.fixtures/$cli.$hash"
}

mock_cli_teardown() {
  local dir="$1"
  [ -d "$dir" ] && rm -rf "$dir"
}

# Simple assertion helpers (bash-style; solo-orchestrator's tests/ pattern)
assert_eq() {
  local expected="$1" actual="$2" msg="${3:-}"
  if [ "$expected" != "$actual" ]; then
    echo "ASSERT FAIL${msg:+ [$msg]}: expected '$expected', got '$actual'" >&2
    return 1
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "ASSERT FAIL${msg:+ [$msg]}: '$haystack' does not contain '$needle'" >&2
    return 1
  fi
}

assert_exit_code() {
  local expected="$1" actual="$2" msg="${3:-}"
  if [ "$expected" != "$actual" ]; then
    echo "ASSERT FAIL${msg:+ [$msg]}: expected exit $expected, got $actual" >&2
    return 1
  fi
}
