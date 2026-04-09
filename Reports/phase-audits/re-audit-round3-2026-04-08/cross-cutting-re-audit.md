# Cross-Cutting Re-Audit (Round 3) -- 2026-04-08

**Auditor Persona:** Chief Compliance Officer / Enterprise Process Auditor
**Scope:** All scripts, hooks, CI pipelines, governance, upgrade paths, evaluation prompts, enforcement model, cross-document consistency
**Methodology:** Fresh evaluation of CURRENT file state -- no inherited assumptions from prior audits
**Date:** 2026-04-08

---

## Summary

| Severity | Count |
|---|---|
| Critical | 4 |
| High | 8 |
| Medium | 12 |
| Low | 6 |
| Informational | 5 |
| **Total** | **35** |

---

## Critical Findings

### CC3-001: User Guide Documents 6 Phase 3 Validation Steps but Code Implements 9

**Severity:** Critical
**Components:** `docs/user-guide.md` line 125, `scripts/process-checklist.sh` line 31

**Evidence:** The User Guide states: "Phase 3 Validation -- all 6 validation types (integration, security, chaos, accessibility, performance, contract) must be completed and results archived." However, `process-checklist.sh` defines `PHASE3_STEPS` with 9 steps: `integration_testing`, `security_hardening`, `chaos_testing`, `accessibility_audit`, `performance_audit`, `contract_testing`, `results_archived`, `pre_launch_preparation`, `legal_review`.

The three undocumented steps (`results_archived`, `pre_launch_preparation`, `legal_review`) are enforced by the state machine but invisible to the Orchestrator reading the User Guide. An Orchestrator following the User Guide will believe Phase 3 is complete after 6 steps and not understand why the gate remains blocked.

**Impact:** Orchestrator confusion. Enforcement blocks legitimate progress. The Orchestrator must reverse-engineer the enforcement system to discover undocumented requirements.

**Recommendation:** Update User Guide Section "Process Enforcement (Tier 2)" to list all 9 Phase 3 steps with descriptions. Alternatively, if `results_archived`, `pre_launch_preparation`, and `legal_review` are intentionally implied rather than enumerated, make them auto-completable or clearly footnoted.

---

### CC3-002: Phase 1 Architecture Checklist Exists in Code but Is Undocumented Everywhere

**Severity:** Critical
**Components:** `scripts/process-checklist.sh` lines 28, 104, 127-141; `docs/builders-guide.md`; `docs/user-guide.md`

**Evidence:** `process-checklist.sh` defines a `PHASE1_STEPS` array: `architecture_selected`, `threat_model_complete`, `data_model_defined`, `ui_scaffolding_done`, `bible_synthesized`. The script also implements `start_phase1()` and the `--start-phase1` argument. The `get_steps_for_process()` function maps `phase1_architecture` to these steps.

However:
- The Builder's Guide Enforcement Model section does not mention Phase 1 process enforcement.
- The User Guide's "Process Enforcement (Tier 2)" section lists only 4 gated processes: Build Loop, UAT Session, Phase 3 Validation, Phase 4 Release. Phase 1 Architecture is not listed.
- The User Guide's Script Reference table lists `process-checklist.sh` as "Phase 2+", contradicting the Phase 1 capability.
- The `--help` output in `process-checklist.sh` (line 68) lists valid processes as `build_loop, uat_session, phase3_validation, phase4_release, phase2_init` -- omitting `phase1_architecture`.

**Impact:** A complete enforcement process exists in code but is invisible to users and partially invisible even in the script's own help text. The Orchestrator has no guidance on when or how to invoke Phase 1 enforcement.

**Recommendation:** Either (a) document Phase 1 architecture enforcement in both the Builder's Guide and User Guide, update the `--help` text, and update the Script Reference table to show "Phase 1+"; or (b) if this is incomplete/experimental, guard it behind a feature flag and add a comment marking it as unreleased.

---

### CC3-003: Phase 4 Release Checklist Has 6 Steps in Code but User Guide Says 5

**Severity:** Critical
**Components:** `docs/user-guide.md` line 126, `scripts/process-checklist.sh` line 32

**Evidence:** The User Guide states: "Phase 4 Release -- rollback must be tested before go-live verification. All 5 release steps required." However, `process-checklist.sh` defines `PHASE4_STEPS` with 6 steps: `production_build`, `rollback_tested`, `go_live_verified`, `monitoring_configured`, `handoff_written`, `handoff_tested`.

The Orchestrator will believe the release is complete after 5 steps when the state machine requires 6. The `handoff_tested` step is undocumented, and its artifact check (line 308-315) requires results in `docs/test-results/*handoff*`.

**Impact:** Same class as CC3-001 -- enforcement blocks progress based on undocumented requirements.

**Recommendation:** Update User Guide to accurately state "All 6 release steps required" and enumerate all steps.

---

### CC3-004: Pre-Commit Gate Does Not Block SOIF_STRICT_CHANGELOG or SOIF_STRICT_SESSION Environment Overrides

**Severity:** Critical
**Components:** `scripts/pre-commit-gate.sh` lines 27-39

**Evidence:** The pre-commit gate blocks agent-initiated `SOIF_FORCE_STEP` and `SOIF_PHASE_GATES` environment variable usage, correctly preventing the agent from downgrading enforcement. However, it does not block `SOIF_STRICT_CHANGELOG=false` or `SOIF_STRICT_SESSION=false`. These variables are less critical (they are CI-level, not session-level), but the inconsistency means the gate's philosophy of "block all enforcement-level overrides" has a gap.

More critically, the gate blocks `SOIF_PHASE_GATES` (line 35) but the pattern `grep -qE 'SOIF_PHASE_GATES'` matches any command containing the string, including legitimate reads like `echo $SOIF_PHASE_GATES`. This over-broad match could block innocuous diagnostic commands.

**Impact:** False positives on diagnostic commands; philosophical inconsistency in which env overrides are guarded.

**Recommendation:** Narrow the grep pattern to match assignment patterns (`SOIF_PHASE_GATES=`) rather than bare string presence. Consider whether `SOIF_STRICT_*` variables need the same gating.

---

## High Findings

### CC3-005: check-phase-gate.sh Uses `local` Keyword Outside Functions

**Severity:** High
**Components:** `scripts/check-phase-gate.sh` lines 240-241, 425-426

**Evidence:** Lines 240-241 use `local p0_files=0` in the main body of the script (not inside a function). Line 425-426 uses `local p3_steps_done`. While bash tolerates `local` outside functions in some versions, it is undefined behavior per POSIX and causes errors in strict shell environments. This is a latent bug that may surface on different systems.

**Impact:** Script failure on Linux distributions with stricter bash configurations or when run under `sh` instead of `bash`.

**Recommendation:** Remove `local` from variable declarations that are not inside functions, or wrap those code sections in functions.

---

### CC3-006: verify-install.sh Missing 12 Scripts from Verification Checklist

**Severity:** High
**Components:** `scripts/verify-install.sh` lines 230-253

**Evidence:** The `check_scripts()` function verifies only 8 scripts: `validate.sh`, `check-phase-gate.sh`, `check-updates.sh`, `resume.sh`, `intake-wizard.sh`, `resolve-tools.sh`, `upgrade-project.sh`, `verify-install.sh`. Missing from verification: `check-changelog.sh`, `check-session-state.sh`, `check-versions.sh`, `check-maintenance.sh`, `pre-commit-gate.sh`, `process-checklist.sh`, `test-gate.sh`, `track-tool-usage.sh`, `session-version-check.sh`, `session-test-gate-check.sh`, `session-end-qdrant-reminder.sh`, `reconfigure-project.sh`.

These missing scripts include the entire Tier 2 process enforcement system (`process-checklist.sh`, `pre-commit-gate.sh`, `test-gate.sh`) and all session hooks. A project could pass `verify-install.sh` with a completely non-functional enforcement system.

**Impact:** Installation verification provides false assurance. A project missing enforcement scripts will not be detected.

**Recommendation:** Add all enforcement-critical scripts to the `check_scripts()` array. At minimum: `process-checklist.sh`, `pre-commit-gate.sh`, `test-gate.sh`, `track-tool-usage.sh`, `check-maintenance.sh`, `session-version-check.sh`, `session-test-gate-check.sh`, `session-end-qdrant-reminder.sh`.

---

### CC3-007: check-phase-gate.sh Phase 3 Process State Cross-Reference Requires jq AND process-state.json but Fails Silently

**Severity:** High
**Components:** `scripts/check-phase-gate.sh` lines 422-433

**Evidence:** The Phase 3 process state cross-reference (lines 422-433) is gated on `[ -f ".claude/process-state.json" ] && command -v jq &>/dev/null`. If either condition fails, the entire check is silently skipped. This means:
1. A project without jq installed gets no Phase 3 process enforcement from the phase gate check.
2. A project where `process-state.json` was never created (e.g., Phase 2 init was never run) gets no warning that process enforcement is inactive.

The Governance Framework mandates Phase 3 validation completion as a gate requirement. Silently skipping this check undermines the gate.

**Impact:** Phase 3 gate can be passed without process checklist completion on systems without jq or where process-state.json is absent.

**Recommendation:** When `process-state.json` is absent and `current_phase >= 3`, emit a warning: "Process enforcement state file missing -- process checklist compliance cannot be verified." Consider making this a FAIL rather than a silent skip for Phase 3+ projects.

---

### CC3-008: CI Pipeline Governance Steps Vulnerable to Script Deletion

**Severity:** High
**Components:** `templates/pipelines/ci/python.yml` lines 90-97, `templates/pipelines/ci/typescript.yml` lines 78-86, `templates/pipelines/ci/other.yml` lines 89-96

**Evidence:** All CI templates include:
```yaml
- name: Governance - Phase gate check
  if: hashFiles('.claude/phase-state.json') != ''
  run: |
    if [ ! -f scripts/check-phase-gate.sh ]; then
      echo "::error::Phase gate check script missing. Framework integrity compromised."
      exit 1
    fi
    bash scripts/check-phase-gate.sh
```

This correctly detects script deletion. However, the changelog and session state checks use `2>/dev/null || true`:
```yaml
run: bash scripts/check-changelog.sh 2>/dev/null || true
```

If these scripts are deleted, the governance step passes silently with no warning or annotation. The `|| true` swallows the "file not found" error. An actor who deletes `check-changelog.sh` and `check-session-state.sh` faces zero CI resistance.

**Impact:** Two governance checks can be silently disabled by deleting files. No CI notification that governance coverage has degraded.

**Recommendation:** Add existence checks for `check-changelog.sh` and `check-session-state.sh` similar to the phase gate check pattern. If the script is missing, emit `::warning::` so the governance gap is visible.

---

### CC3-009: run-reviews.sh Manifest Generation Does Not Validate Review File Content

**Severity:** High
**Components:** `evaluation-prompts/Projects/run-reviews.sh` lines 186-223

**Evidence:** The review manifest (lines 186-223) records the file path and SHA-256 hash of each review file. However, it does not verify that the review file was actually generated by the Claude Code invocation on line 177. If a pre-existing file with the same name exists in the project root (e.g., from a previous review run against a different commit), it gets recorded in the manifest with the NEW commit hash, even though its content corresponds to the OLD commit.

Additionally, the script does not check whether Claude Code exited successfully (line 177 uses `claude -p` without capturing exit code). A failed review produces no output file but the manifest generation continues without noting the failure.

**Impact:** Review manifest may record stale reviews as current. Failed reviews are silently omitted from the manifest without any error indication.

**Recommendation:** (1) Capture and check the exit code of `claude -p`. (2) Before recording in the manifest, verify the review file's modification time is after `REVIEW_TIMESTAMP`. (3) Record failures explicitly in the manifest.

---

### CC3-010: check-phase-gate.sh Runs eval on Tool Resolver Output

**Severity:** High
**Components:** `scripts/check-phase-gate.sh` lines 502-506

**Evidence:** Lines 502-506:
```bash
echo "$auto_installable" | jq -r '.[] | .install_command // empty' | while IFS= read -r cmd; do
  [ -z "$cmd" ] && continue
  echo -e "  ${CYAN}Running:${NC} $cmd"
  eval "$cmd" || echo -e "  ${YELLOW}[WARN]${NC} Command failed: $cmd"
done
```

The `eval "$cmd"` executes commands from the tool matrix JSON files without sanitization. If the tool matrix JSON is modified (either maliciously or through corruption), arbitrary commands execute. While the tool matrix is shipped with the framework, it is a mutable file in the project directory.

**Impact:** Arbitrary code execution from tool matrix data. Supply chain risk if tool matrix files are tampered with.

**Recommendation:** Validate commands against a whitelist of expected patterns (e.g., must start with `brew install`, `pip install`, `npm install`, etc.) before executing. Alternatively, extract only the package name and use a fixed install command template.

---

### CC3-011: process-checklist.sh --reset and --reset-all Have No Authentication Beyond Terminal Check

**Severity:** High
**Components:** `scripts/process-checklist.sh` lines 50-51, `scripts/pre-commit-gate.sh` lines 42-48

**Evidence:** The pre-commit gate blocks agent-initiated `--reset` commands (line 42-48). The `process-checklist.sh` script itself has no additional authentication for `--reset` or `--reset-all` beyond being run from a terminal. While terminal-only execution is documented as the Orchestrator safeguard, any user with shell access to the project can reset all process state without confirmation.

The `--reset` action writes to `process-audit.log` but the `--reset-all` action is not shown in the code section read. If `--reset-all` does not also log, it creates an unaudited bypass path.

**Impact:** Process enforcement can be completely cleared by anyone with shell access. If `--reset-all` does not log, audit trail has a gap.

**Recommendation:** (1) Verify `--reset-all` writes to `process-audit.log`. (2) Add an interactive confirmation prompt for `--reset-all` (similar to the `SOIF_FORCE_STEP` confirmation pattern). (3) Consider requiring an environment variable or flag that confirms Orchestrator intent.

---

### CC3-012: CI Pipeline Templates Do Not Run check-maintenance.sh

**Severity:** High
**Components:** All CI templates (`python.yml`, `typescript.yml`, `other.yml`), `scripts/check-maintenance.sh`

**Evidence:** `check-maintenance.sh` exists and checks monthly, quarterly, and biannual maintenance cadences. However, it is not invoked by any CI pipeline template. The Governance Framework Section X mandates maintenance cadence enforcement with escalation procedures ("If two consecutive monthly security audits are missed, the Senior Technical Authority is notified"). Without CI integration, maintenance cadence violations are only detectable if someone manually runs the script.

**Impact:** Maintenance cadence enforcement is entirely manual. The primary governance control for ongoing compliance has no automated detection in the pipeline that runs on every push.

**Recommendation:** Add a `Governance - Maintenance cadence check` step to all CI templates, similar to the changelog/session checks. Initially as a warning (`|| true`), with documentation on how to make it blocking via an environment variable.

---

## Medium Findings

### CC3-013: check-maintenance.sh Uses Platform-Specific Date Parsing (macOS Primary, Linux Fallback)

**Severity:** Medium
**Components:** `scripts/check-maintenance.sh` lines 30, 51, 72, 92

**Evidence:** Date epoch conversion uses `date -j -f "%Y-%m-%d" "$date" +%s 2>/dev/null || date -d "$date" +%s 2>/dev/null`. The primary path is macOS-specific (`date -j -f`), with GNU date (`date -d`) as fallback. CI runners (Ubuntu) will always take the fallback path. This works but is fragile -- if the fallback fails (e.g., unexpected date format), the `|| echo "0"` final fallback silently skips the check.

**Impact:** Silent check bypass on date parsing failure. No notification that a cadence check was skipped.

**Recommendation:** Add a warning when date parsing produces epoch 0, e.g., `print_warn "Could not parse date '$date' -- maintenance check skipped for this cadence"`.

---

### CC3-014: validate.sh Does Not Check Process Enforcement Hooks Registration

**Severity:** Medium
**Components:** `scripts/validate.sh` lines 71-83

**Evidence:** `validate.sh` Section "Git & Hooks" checks for `.git/hooks/pre-commit` (the security pre-commit hook) but does not verify Claude Code hook registration in `.claude/settings.json`. The PreToolUse, PostToolUse, SessionStart, and Stop hooks are the mechanism for Tier 2 enforcement. `verify-install.sh` does check hooks (lines 280-332), but `validate.sh` does not, creating a split where one validation tool detects hook gaps and the other does not.

**Impact:** `validate.sh` can report "all checks passed" while the entire process enforcement system is unregistered.

**Recommendation:** Add a "Process Enforcement Hooks" section to `validate.sh` that checks `.claude/settings.json` for the four hook registrations, or add a cross-reference instruction: "For full hook verification, run scripts/verify-install.sh".

---

### CC3-015: process-checklist.sh check-commit-ready Exempts All .md/.json/.yml/.yaml/.toml/.tmpl Files

**Severity:** Medium
**Components:** `scripts/process-checklist.sh` lines 745-756

**Evidence:** The `check_commit_ready` function classifies commits as "docs-only" if all staged files match `\.(md|json|yml|yaml|toml|tmpl)$`. Documentation commits bypass all process enforcement. This means:
1. Modifying `.claude/phase-state.json` (a JSON file) bypasses enforcement -- an actor could advance `current_phase` without completing gate requirements.
2. Modifying `.claude/process-state.json` bypasses enforcement -- an actor could mark steps complete by editing the state file directly.
3. Modifying CI pipeline YAML bypasses enforcement -- security-weakening CI changes are not gated.

**Impact:** State files and CI configuration can be modified without process enforcement. The "docs-only" exemption is too broad.

**Recommendation:** Exclude `.claude/*.json` and `.github/workflows/*.yml` from the "docs-only" classification. These are infrastructure files, not documentation.

---

### CC3-016: upgrade-project.sh Has No Rollback Mechanism

**Severity:** Medium
**Components:** `scripts/upgrade-project.sh`

**Evidence:** The upgrade script modifies `phase-state.json`, `tool-preferences.json`, `CLAUDE.md`, `PROJECT_INTAKE.md`, and `APPROVAL_LOG.md` directly. There is no pre-upgrade snapshot, no dry-run mode, and no rollback instruction. If an upgrade produces incorrect state (e.g., wrong track detected, template corruption), the Orchestrator must manually reverse the changes.

**Impact:** Irreversible state changes on upgrade failure. Recovery requires manual git operations.

**Recommendation:** (1) Create a snapshot of all modified files before upgrading (e.g., copy to `.claude/pre-upgrade-backup/`). (2) Add a `--dry-run` flag to preview changes without applying them.

---

### CC3-017: run-reviews.sh Hardcodes Review Output Filenames Without Versioning Logic

**Severity:** Medium
**Components:** `evaluation-prompts/Projects/run-reviews.sh` lines 204, 228

**Evidence:** Review output files are hardcoded as `${reviewer}-review-v1.md` (line 204). Running reviews a second time against a different commit overwrites the previous review files without warning. The manifest records the new SHA-256, making the overwrite look intentional. There is no version incrementing logic.

**Impact:** Review evidence from prior commits is silently destroyed. If a Phase 3 gate reviewer asked "show me the security review from the Phase 2 code freeze," the file may contain Phase 3 review content.

**Recommendation:** Include the commit short hash in the filename (e.g., `engineer-review-v1-abc1234.md`) or increment the version suffix when a file already exists.

---

### CC3-018: check-versions.sh Hardcodes Brew Path Prepend Without Platform Check

**Severity:** Medium
**Components:** `scripts/check-versions.sh` lines 15-18

**Evidence:** Lines 15-18 unconditionally attempt `brew --prefix` and prepend to PATH. On Linux systems without Homebrew, this runs `brew --prefix` which outputs an error to stderr (suppressed by `2>/dev/null || true`). While harmless, it adds latency on every invocation on non-macOS systems.

**Impact:** Minor performance degradation on Linux. The `|| true` prevents failures but the subprocess fork is unnecessary.

**Recommendation:** Guard with `if [ "$(uname -s)" = "Darwin" ]` before attempting `brew --prefix`.

---

### CC3-019: Session Start Hook Resets Tool Usage but Does Not Validate Prior Session Completeness

**Severity:** Medium
**Components:** `scripts/session-test-gate-check.sh` lines 8-21

**Evidence:** Lines 8-21 unconditionally create a fresh `tool-usage.json` on every session start. This destroys any accumulated tool usage data from the prior session. If the prior session ended abnormally (crash, network disconnect) before the Stop hook could run, the Qdrant storage reminder and tool usage summary are lost.

**Impact:** Tool usage data from crashed sessions is permanently lost. No warning that the prior session ended without the Stop hook firing.

**Recommendation:** Before overwriting, check if the prior `tool-usage.json` has `qdrant_store_called: false` with commits recorded. If so, emit a warning: "Prior session had source commits but Qdrant was not used for storage."

---

### CC3-020: Governance Framework Mandates Quarterly Portfolio Review but No Script Enforces It

**Severity:** Medium
**Components:** `docs/governance-framework.md` Section X ("Portfolio Scaling"), all scripts

**Evidence:** The Governance Framework mandates: "A quarterly portfolio review conducted by the Senior Technical Authority evaluates each Solo Orchestrator application." It further states: "If the quarterly review is not completed within 30 days of the scheduled date, the Senior Technical Authority MUST escalate to the CIO."

No script, CI step, or hook enforces or even detects whether the quarterly portfolio review has been completed. `check-maintenance.sh` checks monthly/quarterly/biannual technical cadences but not governance cadences.

**Impact:** The highest-level governance accountability mechanism is entirely trust-based. There is no automated detection of missed quarterly reviews.

**Recommendation:** Add a quarterly governance check to `check-maintenance.sh` that looks for a dated entry in `APPROVAL_LOG.md` or a dedicated governance review log. This aligns the script's coverage with the Governance Framework's requirements.

---

### CC3-021: User Guide's POC Mode Reference States "All 8 Pre-Conditions" but Governance Lists 6

**Severity:** Medium
**Components:** `docs/user-guide.md` line 215, `docs/governance-framework.md` Section V

**Evidence:** The User Guide's POC Modes table states Private POC defers "All 8 pre-conditions." However, the User Guide's own Section 1.2 lists "The 6 blocking pre-conditions" (lines 189-201). The Governance Framework's Pre-Phase 0 section also describes 6 pre-conditions.

The discrepancy may be because the intake wizard adds 2 additional POC-specific gates beyond the 6 core governance pre-conditions. But this is not explained, and the number mismatch will confuse Orchestrators trying to reconcile the documents.

**Impact:** Document inconsistency. Orchestrators cannot determine the authoritative count of pre-conditions to resolve.

**Recommendation:** Reconcile the count. If Private POC defers 6 pre-conditions, change to "All 6." If there are genuinely 8 (the 6 plus exit criteria and time allocation), enumerate them explicitly.

---

### CC3-022: check-phase-gate.sh Interactive Prompts in a CI Context

**Severity:** Medium
**Components:** `scripts/check-phase-gate.sh` lines 500-506, 522-548

**Evidence:** The tool resolution section (lines 500-548) includes `read -rp` interactive prompts for auto-installing tools and starting Qdrant. If `check-phase-gate.sh` is invoked in CI (it is referenced in all CI templates), these prompts will hang the pipeline indefinitely waiting for input.

The mitigation is that these prompts are behind conditional checks (`[ -f "$TOOL_PREFS" ] && [ -x "$RESOLVER" ] && command -v jq &>/dev/null`) that may not trigger in CI. But the risk exists for any CI runner that has these files present.

**Impact:** CI pipeline hang if tool resolution conditions are met in the CI environment.

**Recommendation:** Guard interactive prompts with `[ -t 0 ]` (test for interactive terminal) so they are skipped in CI. The pattern is already used in `process-checklist.sh` line 362 for `SOIF_FORCE_STEP`.

---

### CC3-023: Approval Log Integrity Check Has a Subtle Regex Gap

**Severity:** Medium
**Components:** All CI templates, `Governance - Approval log integrity` step

**Evidence:** The approval log integrity check uses:
```bash
git diff origin/main...HEAD -- APPROVAL_LOG.md | grep -qE '^\-[^-]'
```

This checks for lines starting with `-` (deletion) that are not `---` (YAML frontmatter dividers). However, the pattern `^\-[^-]` also matches diff hunk headers like `-## Phase 0` (a removed markdown heading). The intent is to catch deleted content lines, but the regex does not account for the diff context prefix. A more precise pattern would be `^-[^-]` (without escaping, grep treats `\-` as literal hyphen which is the same as `-` in a character class, so this works but is unnecessarily obscure).

More substantively: if an Orchestrator replaces the entire APPROVAL_LOG.md content via `git checkout -- APPROVAL_LOG.md` followed by `git add`, the diff will show all original lines as deletions. The check catches this. But if the Orchestrator resets to a prior commit's version of the file using `git show <old_commit>:APPROVAL_LOG.md > APPROVAL_LOG.md`, the deletions of newer entries will be detected. This is correct behavior -- noting for completeness.

**Impact:** Low practical impact. The regex works correctly for its purpose despite the escaping oddity.

**Recommendation:** No action required. This is confirmation that the control works as designed. Consider adding a comment in the CI template explaining what the regex catches and why.

---

### CC3-024: reconfigure-project.sh Does Not Update process-state.json or build-progress.json

**Severity:** Medium
**Components:** `scripts/reconfigure-project.sh`

**Evidence:** When the project track is changed (e.g., light to standard), `reconfigure-project.sh` updates `phase-state.json` and `tool-preferences.json`. However, it does not update `process-state.json` or `build-progress.json`. If a project upgrades from light to standard mid-Phase 2, the process enforcement state may be inconsistent with the new track's requirements (e.g., standard track may require additional Phase 3 steps that are not reflected in the process state).

**Impact:** Track upgrade may leave process enforcement state inconsistent with the new track's requirements.

**Recommendation:** Add a warning when track changes: "Process state may need to be re-initialized for the new track. Run scripts/process-checklist.sh --status to verify."

---

## Low Findings

### CC3-025: helpers.sh prompt_choice and prompt_input Are Duplicated Between helpers.sh and intake-wizard.sh

**Severity:** Low
**Components:** `scripts/lib/helpers.sh` lines 137-169, `scripts/intake-wizard.sh` lines 34-77

**Evidence:** `helpers.sh` defines `prompt_input()` and `prompt_choice()`. `intake-wizard.sh` defines its own versions with the same names but different signatures (the intake versions add pause detection and suggestion support). Since `intake-wizard.sh` sources `helpers.sh` first and then defines its own versions, the helpers versions are shadowed. This works but means the intake wizard silently overrides shared functions. Any future script that sources both will get unpredictable behavior.

**Impact:** Maintenance risk. Function signature divergence makes refactoring error-prone.

**Recommendation:** Rename the intake wizard's versions to `intake_prompt_input()` and `intake_prompt_choice()` to avoid shadowing.

---

### CC3-026: check-session-state.sh Has No Mechanism to Detect CLAUDE.md Template Defaults

**Severity:** Low
**Components:** `scripts/check-session-state.sh`, `scripts/validate.sh` lines 312-332

**Evidence:** `check-session-state.sh` checks CLAUDE.md freshness by commit age and commit count. `validate.sh` checks for template defaults ("Features built: none yet"). Neither check is aware of the other. A CLAUDE.md that was recently committed but still contains template defaults passes `check-session-state.sh` (it is "fresh") but fails `validate.sh` (it has defaults). The checks should be complementary but they are independent with no cross-reference.

**Impact:** Misleading freshness signal. A recently-committed but never-customized CLAUDE.md appears healthy.

**Recommendation:** Add a template-default check to `check-session-state.sh` or add a cross-reference message: "For content validation, run scripts/validate.sh."

---

### CC3-027: Other Language CI Template (other.yml) Has Blocking Placeholders for Dependency and License Checks

**Severity:** Low
**Components:** `templates/pipelines/ci/other.yml` lines 48-61

**Evidence:** The `other.yml` template includes dependency audit and license check steps that `exit 1` with a TODO message. This is intentional (the template documents that customization is required). However, the exit 1 means that any project using this template will have a permanently failing CI pipeline until the Orchestrator customizes these steps. This is by design but is worth noting.

**Impact:** Projects using unsupported languages have a failing CI pipeline from init. This could frustrate Orchestrators who expect a working baseline.

**Recommendation:** The current behavior is acceptable as a forcing function. Consider adding a comment at the top of the file: "This template REQUIRES customization. CI will fail until language-specific steps are configured."

---

### CC3-028: intake-wizard.sh Python Dependency for JSON Operations

**Severity:** Low
**Components:** `scripts/intake-wizard.sh` lines 168-186, 216-235, 243-256

**Evidence:** The intake wizard uses `python3` for JSON parsing and writing (`parse_suggestions()`, `init_progress()`, `save_section()`, `save_answer()`, `load_progress()`). All other scripts use `jq` for JSON operations. If python3 is unavailable but jq is available, the intake wizard silently fails JSON operations (the `if command -v python3` guard means operations are skipped without error). The upgrade script (`upgrade-project.sh`) also requires python3 (line 140).

**Impact:** Inconsistent tooling requirements. The intake wizard has a hidden python3 dependency that is not validated by `verify-install.sh` or listed as required in the User Guide prerequisites.

**Recommendation:** List python3 as a required dependency for the intake wizard in the User Guide. Alternatively, migrate JSON operations to jq for consistency.

---

### CC3-029: track-tool-usage.sh Uses set +e Globally

**Severity:** Low
**Components:** `scripts/track-tool-usage.sh` line 10

**Evidence:** The script uses `set +e` (line 10) to prevent any error from blocking the agent. This is documented and intentional ("a tracking failure should not interrupt a build loop"). However, this means any bug in the script (e.g., writing to a wrong path, corrupting tool-usage.json) will silently degrade rather than fail visibly.

**Impact:** Tool usage tracking bugs are undetectable during development. Corrupted `tool-usage.json` will cause downstream issues in `pre-commit-gate.sh` and `session-end-qdrant-reminder.sh`.

**Recommendation:** The current approach is correct for a PostToolUse hook. Consider adding a periodic validation of `tool-usage.json` structure (e.g., in `session-test-gate-check.sh`): if the file exists but is invalid JSON, recreate it.

---

### CC3-030: check-versions.sh Uses grep -oP (PCRE) Which Is Not Available on macOS Default grep

**Severity:** Low
**Components:** `scripts/check-versions.sh` line 97

**Evidence:** Line 97 in `get_latest_version()`:
```bash
git ls-remote --tags "$package" 2>/dev/null | grep -oP 'refs/tags/v?\K[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -1
```

macOS ships BSD grep which does not support `-P` (Perl regex) or `\K` (lookbehind). This path is only reached for `git_tag` method lookups, which may not be exercised in standard configurations. If Homebrew grep is installed, the `PATH` prepend at the script's start (lines 15-18) may resolve it.

**Impact:** `git_tag` version lookups fail silently on macOS without Homebrew grep.

**Recommendation:** Replace with a POSIX-compatible alternative: `grep -oE 'refs/tags/v?[0-9]+\.[0-9]+\.[0-9]+' | sed 's|refs/tags/v\?||'`.

---

## Informational Findings

### CC3-031: Governance Framework References "Section XIII" for Handoff Test but No Section XIII Exists

**Severity:** Informational
**Components:** `docs/governance-framework.md` line 598

**Evidence:** Line 598 states "Has been tested via the handoff test (see Section XIII)." The governance framework has sections I through XI visible in the read content. If Section XIII exists beyond what was read, this is a non-issue. If the section numbering was changed during editing, this is a dead cross-reference.

**Recommendation:** Verify Section XIII exists. If not, update the cross-reference to point to the correct section (the handoff test details appear to be in Section X under "Handoff Test (Mandatory Per Project)").

---

### CC3-032: Builder's Guide Appendix A Lists `docs/ADR documentation/` but Common Convention Is `docs/adr/`

**Severity:** Informational
**Components:** `docs/builders-guide.md` line 1550

**Evidence:** Appendix A specifies the ADR location as `docs/ADR documentation/NNNN-title.md`. The space in the directory name and mixed-case "ADR documentation" is unusual. Most ADR conventions use `docs/adr/` or `docs/architecture-decisions/`. The space will cause issues with shell commands that do not properly quote paths.

**Recommendation:** Evaluate whether to rename to a more conventional path. If the current naming is intentional, ensure all scripts that reference ADR paths handle spaces correctly.

---

### CC3-033: CI Templates Pin GitHub Actions by Commit Hash (Good Practice)

**Severity:** Informational
**Components:** All CI templates

**Evidence:** All CI templates pin third-party GitHub Actions by commit SHA:
- `semgrep/semgrep-action@713efdd345f3035192eaa63f56867b88e63e4e5d`
- `gitleaks/gitleaks-action@ff98106e4c7b2bc287b24eaf42907196329070c7`

This is excellent supply-chain security practice. The inline comments document the corresponding tag versions.

**Recommendation:** No action. This is a positive finding.

---

### CC3-034: run-reviews.sh Provenance Section Includes Commit Hash and Timestamp

**Severity:** Informational
**Components:** `evaluation-prompts/Projects/run-reviews.sh` lines 158-169

**Evidence:** Each review prompt includes a provenance section with the exact commit hash, timestamp, module, and reviewer identity. The review manifest also records SHA-256 hashes of output files. This creates a strong audit trail for review traceability.

**Recommendation:** No action. This is a positive finding. Consider also recording the Claude model version used, which can be obtained from the CLI.

---

### CC3-035: Enforcement Model Has Three Tiers with Clear Responsibility Boundaries

**Severity:** Informational
**Components:** `docs/builders-guide.md` lines 85-93, `docs/user-guide.md` lines 80-117

**Evidence:** The enforcement model clearly delineates:
- **Tier 1 (CI):** Mechanical hard blocks. Cannot be bypassed without modifying CI config.
- **Tier 2 (Hooks + Process Checklist):** Mechanical blocks within Claude Code sessions. Bypass requires Orchestrator terminal access.
- **Tier 3 (LLM Instructions):** Guided, no automated backstop.

The User Guide correctly states: "Only the CI pipeline is a hard enforcement boundary." The Builder's Guide reinforces this. The three-tier model provides defense in depth while honestly acknowledging where enforcement depends on human discipline.

**Recommendation:** No action. The enforcement model is well-designed and honestly documented.

---

## Cross-Document Consistency Matrix

| Topic | Builder's Guide | User Guide | Governance Framework | Scripts | CI Templates | Status |
|---|---|---|---|---|---|---|
| Phase 3 step count | Not specified | "6 validation types" | N/A | 9 steps | N/A | **MISMATCH** (CC3-001) |
| Phase 4 step count | Not specified | "5 release steps" | N/A | 6 steps | N/A | **MISMATCH** (CC3-003) |
| Phase 1 enforcement | Not mentioned | Not mentioned | N/A | Implemented | N/A | **MISMATCH** (CC3-002) |
| Pre-conditions count | N/A | "6 blocking" + "All 8" | 6 defined | N/A | N/A | **MISMATCH** (CC3-021) |
| Approval log append-only | Mentioned | Mentioned | Specified | append check in CI | Enforced | Consistent |
| TDD enforcement timing | "commit time, not file-write" | Described | N/A | Implemented at commit gate | N/A | Consistent |
| Maintenance cadence | Monthly/Quarterly/Biannual | Monthly/Quarterly/Biannual | Monthly/Quarterly/Biannual + credential rotation | 3 cadences checked | **Not integrated** | **GAP** (CC3-012) |
| SOIF_FORCE_STEP gating | N/A | Documented | N/A | Terminal check + pre-commit block | N/A | Consistent |
| Security scanning in CI | Required | Required | Required | N/A | Semgrep + gitleaks + dep audit + license | Consistent |
| Penetration testing | Standard+ track | Standard+ track | Light: not required, Standard: required | Checked in check-phase-gate.sh | N/A | Consistent |
| check-maintenance.sh in CI | N/A | Not referenced in CI | Cadence enforcement mandated | Script exists | **Missing** | **GAP** (CC3-012) |
| process-state.json validation | N/A | N/A | N/A | validate.sh checks JSON validity | N/A | Consistent |
| Hook registration | init.sh registers all 4 hooks | Described in script reference | N/A | verify-install.sh checks hooks | N/A | Consistent |

---

## Bypass Analysis

This section evaluates how an actor (malicious agent or careless Orchestrator) could circumvent the enforcement system.

### Bypass Path 1: Edit State Files Directly

**Method:** Modify `.claude/process-state.json` to mark all steps as complete. Modify `.claude/phase-state.json` to advance `current_phase`.

**Detection:** State file modifications are classified as "docs-only" commits (CC3-015) and bypass process enforcement. `git diff` in the CI approval log integrity check does not cover state files. The `check-phase-gate.sh` script validates state file consistency against artifacts but does not detect fabricated step completions.

**Mitigation Effectiveness:** Low. This bypass is detectable via git history review but not mechanically prevented.

### Bypass Path 2: Delete Enforcement Scripts

**Method:** Delete `scripts/process-checklist.sh` and `scripts/pre-commit-gate.sh`.

**Detection:** CI detects missing `check-phase-gate.sh` (hard error). CI does NOT detect missing `process-checklist.sh` or `pre-commit-gate.sh`. `verify-install.sh` does not check for these scripts (CC3-006). Hook invocations would fail but Claude Code may not surface the failure clearly.

**Mitigation Effectiveness:** Low for process enforcement scripts. High for phase gate script.

### Bypass Path 3: Modify CI Pipeline

**Method:** Edit `.github/workflows/ci.yml` to remove governance steps.

**Detection:** This is a "docs-only" commit (YAML file, CC3-015) and bypasses process enforcement. CI cannot detect its own modification. Branch protection rules (if configured) would require PR review. The `check-updates.sh` script would flag the CI pipeline as "differs from upstream template."

**Mitigation Effectiveness:** Depends entirely on branch protection configuration, which the framework recommends but does not enforce.

### Bypass Path 4: Set SOIF_PHASE_GATES=warn in CI Environment

**Method:** Add `SOIF_PHASE_GATES: "warn"` to the CI environment variables.

**Detection:** The pre-commit gate blocks this at the agent level (CC3-004), but it does not protect CI. Anyone with repository settings access can add this environment variable to GitHub Actions, downgrading all phase gate checks from blocking to warning.

**Mitigation Effectiveness:** The pre-commit gate protects agent sessions. CI protection depends on GitHub repository settings access controls.

---

## Recommendation Priority

| Priority | Finding | Effort |
|---|---|---|
| 1 (Immediate) | CC3-001, CC3-002, CC3-003: Step count mismatches between docs and code | Low (doc update) |
| 2 (Next sprint) | CC3-006: verify-install.sh missing scripts | Low (add to array) |
| 3 (Next sprint) | CC3-015: State file modification bypass via docs-only exemption | Medium (code change) |
| 4 (Next sprint) | CC3-012: check-maintenance.sh not in CI | Low (add CI step) |
| 5 (Next sprint) | CC3-005: `local` outside functions | Low (code fix) |
| 6 (Near-term) | CC3-004: Overly broad SOIF_PHASE_GATES pattern match | Low (code fix) |
| 7 (Near-term) | CC3-008: Silent governance step deletion | Low (add existence checks) |
| 8 (Near-term) | CC3-007: Silent skip of Phase 3 process check | Low (add warning) |
| 9 (Near-term) | CC3-014: validate.sh hook verification gap | Medium (add section) |
| 10 (Planning) | CC3-010: eval on tool matrix data | Medium (validation logic) |
| 11 (Planning) | CC3-022: Interactive prompts in CI-callable script | Low (add terminal check) |
| 12 (Planning) | CC3-011: Reset authentication and audit logging | Medium (add confirmation) |

---

## Auditor Certification

This audit was conducted by evaluating the current file state of all specified components as of 2026-04-08. Every finding is traced to specific file paths and line numbers. The enforcement model is well-designed at its foundation -- the findings above identify gaps between what the documentation promises and what the infrastructure mechanically enforces, plus specific bypass paths that an informed actor could exploit.

The most significant pattern across findings is **step count divergence** (CC3-001, CC3-002, CC3-003): the code implements more enforcement steps than the documentation describes. This creates a trust gap where the Orchestrator cannot predict the system's behavior from the documentation alone. Resolving the documentation mismatches is the highest-priority, lowest-effort improvement.
