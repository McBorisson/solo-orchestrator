# Solo Orchestrator — Full Test Suite Report

**Date:** 2026-04-03
**Tester:** Claude Opus 4.6 (automated)

---

## Test Matrix

| Run | Deployment | Platform | Language | Track | Result |
|---|---|---|---|---|---|
| 1 | Personal | Web | TypeScript | Light | PASS |
| 2 | Organizational | Desktop | Rust | Standard | PASS |
| 3 | Organizational | Mobile | Dart | Full | PASS |
| 4 | Organizational | CLI | Python | Standard | PASS |

---

## Run Results

### Run 1: Personal / Web / TypeScript / Light

**init.sh:** Completed successfully. All security tools detected. Lighthouse installed (web-only). Development Guardrails for Claude Code clone failed (repo unavailable) — fallback pre-commit hook installed correctly.

**Generated files:** 24 files across expected directories. CI pipeline (TypeScript), release pipeline (web), web platform module, all suggestion files, all scripts present.

**validate.sh:** 2 warnings (Development Guardrails not installed, blank Intake fields), 0 errors. All framework files, Git, hooks, CI, security tools validated.

**resume.sh:** Runs. Phase shows "unknown" (bug — see findings below). Git log shows init commit correctly.

**intake-wizard.sh --help:** Works correctly.

**CLAUDE.md:** Correctly customized with project name, platform, track, language, framework references.

---

### Run 2: Organizational / Desktop / Rust / Standard

**init.sh:** Completed successfully. Desktop platform module selected. Rust runtime detected.

**Generated files:** 24 files. Desktop platform module present. Release pipeline has 4 TODOs (expected — code signing + distribution config).

**validate.sh:** 2 warnings (same as Run 1), 0 errors. Rust runtime validated.

**CLAUDE.md:** Contains organizational deployment note ("verify pre-Phase 0 pre-conditions").

---

### Run 3: Organizational / Mobile / Dart / Full

**init.sh:** Completed successfully. Mobile platform module selected. Flutter runtime detected.

**Generated files:** 24 files. Mobile platform module present. Release pipeline has 11 TODOs (expected — iOS + Android signing, store credentials).

**validate.sh:** 2 warnings, 0 errors. Flutter runtime validated.

---

### Run 4: Organizational / CLI / Python / Standard

**init.sh:** Completed successfully. No platform module for CLI (expected — logged as INFO). Python runtime detected.

**Generated files:** 23 files (no platform module file). Release pipeline has 3 TODOs.

**validate.sh:** 2 warnings, 0 errors. Python 3.14.3 validated. CLI platform correctly noted as "no platform module."

---

## Script Validation Summary

| Script | Syntax | --help | Runtime | Issues Found |
|---|---|---|---|---|
| `init.sh` | PASS | PASS | PASS (4 runs) | 1 bug fixed during testing (git clone + set -e) |
| `intake-wizard.sh` | PASS | PASS | N/A (interactive) | 3 critical bugs, 1 design flaw |
| `validate.sh` | PASS | N/A | PASS (4 runs) | 2 bugs, 1 dead code, 1 portability issue |
| `resume.sh` | PASS | N/A | PASS (4 runs) | 1 bug (phase always "unknown") |
| `check-phase-gate.sh` | PASS | N/A | PASS (4 runs) | 0 bugs |
| `check-updates.sh` | PASS | N/A | Not tested | N/A |

---

## Bugs Found

### Critical (will fail at runtime)

**BUG-1: `intake-wizard.sh` — `save_answer` breaks on single quotes in user input**
- **Location:** `scripts/intake-wizard.sh` line ~260
- **Issue:** The `save_answer` function uses triple-quoted Python strings (`'''$value'''`) with shell variable interpolation. If the user types `it's a REST API`, the Python code becomes syntactically invalid.
- **Impact:** Script aborts mid-section. Progress file may be left inconsistent.
- **Fix:** Use `sys.argv` instead of shell interpolation:
  ```bash
  python3 -c "
  import json, sys
  key, value = sys.argv[1], sys.argv[2]
  with open('$PROGRESS_FILE') as f: data = json.load(f)
  data['answers'][key] = value
  with open('$PROGRESS_FILE', 'w') as f: json.dump(data, f, indent=2)
  " "$key" "$value"
  ```

**BUG-2: `intake-wizard.sh` — `init_progress` breaks on single quotes in PROJECT_DESCRIPTION**
- **Location:** `scripts/intake-wizard.sh` line ~206-225
- **Issue:** Same class of bug. Shell variables injected into Python string literals.
- **Fix:** Same approach — use `sys.argv` for all user-provided values.

**BUG-3: `intake-wizard.sh` — `load_progress` shell injection via `eval`**
- **Location:** `scripts/intake-wizard.sh` line ~277-294
- **Issue:** Python output is `eval`'d directly. If the saved project name contains single quotes (stored in JSON from a previous run), `eval` breaks or executes arbitrary shell commands.
- **Fix:** Use `declare` or source a temporary file instead of `eval`. Or sanitize Python output to escape shell-special characters.

**BUG-4: `validate.sh` — `((warnings++))` crashes under `set -e` when not in `||` clause**
- **Location:** `scripts/validate.sh` line ~30-31
- **Issue:** `((0++))` returns exit code 1 in bash. If the first `warn()` call is from an `if` block (not an `||` clause), the script aborts.
- **Fix:** Use `warnings=$((warnings + 1))` instead of `((warnings++))`.

**BUG-5: `resume.sh` — phase regex expects quoted string but `current_phase` is bare integer**
- **Location:** `scripts/resume.sh` line ~24
- **Issue:** Regex `"[^"]*"` after `current_phase:` won't match `0` (a bare integer). Phase is always "unknown".
- **Fix:** Change regex to match both quoted strings and bare integers:
  ```bash
  PHASE=$(grep -o '"current_phase"[[:space:]]*:[[:space:]]*[0-9]*' .claude/phase-state.json | grep -o '[0-9]*' || echo "unknown")
  ```

### High (wrong behavior)

**BUG-6: `validate.sh` — BSD grep on macOS doesn't support `\|` in BRE**
- **Location:** `scripts/validate.sh` line ~369
- **Issue:** Competency matrix checks use `grep -qi "$ci_check"` where `$ci_check` contains `\|` (BRE alternation). On macOS BSD grep, `\|` is not supported in BRE — checks silently pass when they should fail.
- **Fix:** Use `grep -qiE` and change `\|` to `|`.

**BUG-7: `validate.sh` — `has_no` variable can be empty, breaking `-eq` comparison**
- **Location:** `scripts/validate.sh` line ~377
- **Issue:** If `grep` returns no matches, `has_no` is empty. `[ "" -eq 0 ]` fails with "integer expression expected."
- **Fix:** Change `|| true` to `|| echo "0"`.

**BUG-8: `intake-wizard.sh` — `check_pause` doesn't work inside `$(...)` subshells**
- **Location:** `scripts/intake-wizard.sh` line ~55
- **Issue:** Every `prompt_input` call uses command substitution (`local var=$(prompt_input ...)`). The `exit 0` inside `check_pause` only exits the subshell, not the main script. Typing "pause" stores an empty string and continues to the next question.
- **Fix:** Rearchitect to use a global variable and check after each prompt, or use a trap-based approach.

### Medium (fixed during testing)

**BUG-9: `init.sh` — `git clone` failure kills script under `set -e`** (FIXED)
- **Location:** `init.sh` line 474
- **Issue:** `git clone` of Development Guardrails repo fails and `set -e` aborts before reaching the fallback handler.
- **Fix applied:** Added `|| true` to the git clone command.

---

## Dead Code

| File | Item | Impact |
|---|---|---|
| `validate.sh` | `CYAN` color variable defined but never used | Cosmetic — remove |
| `init.sh` | Duplicate `.gitignore` entries (base + language sections both include `venv/`, `__pycache__/`, `dist/`, `build/`) | No functional impact — deduplicate for clarity |

---

## Optimization Opportunities

### High Impact

**OPT-1: `intake-wizard.sh` — 3 Python processes per `save_answer` call**
Currently spawns 3 `python3` processes per answer (~100+ total for a full intake). Replacing with a single `python3 -c` using `sys.argv` (which also fixes BUG-1) reduces this to 1 process per answer.

**OPT-2: `intake-wizard.sh` — re-reads/re-writes entire JSON on every `save_answer`**
~80 full file read/write cycles for a complete intake. Batch approach: accumulate answers in shell variables, write once per section in `save_section`.

### Medium Impact

**OPT-3: `init.sh` — duplicate `uname -s` calls**
`os_type` is computed separately in `check_prerequisites`, `install_tools`, and `install_language_runtime`. Could be computed once globally.

### Low Impact

**OPT-4: `check-phase-gate.sh` — triplicated gate-check logic**
Three identical patterns for phase 0->1, 1->2, 3->4 could be a function.

**OPT-5: `resume.sh` — 4 separate grep/sed passes on CLAUDE.md**
Could be a single `awk` pass.

---

## Portability Issues

| Issue | Platform | Fix |
|---|---|---|
| `validate.sh` uses `\|` in BRE (BUG-6) | macOS (BSD grep) | Use `grep -E` with `|` |
| `init.sh` `prompt_choice` has no input validation | All | Add while loop with range check (intake-wizard.sh has this, init.sh doesn't) |

---

## Test Artifacts

All 4 test projects created at `/tmp/solo-test-runs/`:
- `/tmp/solo-test-runs/test-web-app` (Personal/Web/TypeScript/Light)
- `/tmp/solo-test-runs/test-desktop-app` (Organizational/Desktop/Rust/Standard)
- `/tmp/solo-test-runs/test-mobile-app` (Organizational/Mobile/Dart/Full)
- `/tmp/solo-test-runs/test-cli-tool` (Organizational/CLI/Python/Standard)

---

## Recommendations

### Fix immediately (blocks real usage):
1. BUG-1, BUG-2, BUG-3: `intake-wizard.sh` quoting/injection issues — the wizard will fail the first time someone types an apostrophe
2. BUG-4: `validate.sh` `((warnings++))` — could crash on first warning
3. BUG-5: `resume.sh` phase regex — phase is always "unknown"
4. BUG-6: `validate.sh` macOS grep compatibility

### Fix before release:
5. BUG-7: `validate.sh` empty `has_no` variable
6. BUG-8: `intake-wizard.sh` pause mechanism design flaw
7. OPT-1: Reduce Python process spawning in intake wizard

### Nice to have:
8. OPT-3: Deduplicate `uname` calls
9. Dead code cleanup (CYAN variable, duplicate .gitignore entries)
10. OPT-4, OPT-5: Minor refactoring
