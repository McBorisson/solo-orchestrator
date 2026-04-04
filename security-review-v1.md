# Security Assessment: Solo Orchestrator Framework v1.0

**Assessment Date:** 2026-04-02
**Assessor Role:** SVP, IT Security (20+ years — AppSec, infrastructure, compliance, risk management)
**Assessment Type:** Read-only codebase security review (fresh evaluation, no prior bias)
**Scope:** All files in the solo-orchestrator repository
**Classification:** Confidential — Assessment Results

---

## Security Executive Summary

The Solo Orchestrator Framework is a structured development methodology that orchestrates AI-assisted software construction through Claude Code (Anthropic). It consists of one executable shell script (`init.sh`), three utility scripts (`validate.sh`, `check-phase-gate.sh`, `check-updates.sh`), CI/CD pipeline templates for 8 languages and 4 platforms, and comprehensive methodology documentation. The framework does not execute in production, does not process user data, and does not run a persistent service. Its security impact is indirect: it shapes the security posture of applications built under its guidance.

The framework operates on an explicitly documented **three-tier enforcement model**: Tier 1 (CI pipeline) provides hard mechanical enforcement — builds fail on SAST findings, secret detection, dependency vulnerabilities, and license violations. Tier 2 (pre-commit hooks) provides early warning and blocking — gitleaks blocks commits containing secrets, Semgrep blocks commits with OWASP Top 10 findings, and a test co-location heuristic warns on missing tests. Tier 3 (CLAUDE.md instructions and Builder's Guide procedures) provides guided behavior for the LLM agent. The framework is transparent about which tier each control occupies, with a user-facing table classifying every mechanism.

The mechanical enforcement layer is substantive. Every CI pipeline template includes Semgrep SAST with targeted security rulesets (`p/owasp-top-ten` + `p/security-audit`), gitleaks secret scanning, language-specific dependency auditing, and license compliance checking — all as build-blocking steps. Security-critical GitHub Actions (semgrep, gitleaks, osv-scanner) are pinned to commit SHAs, not mutable tags. The pre-commit hook is mechanically installed by `init.sh` with three checks (gitleaks, Semgrep, test co-location). The claude-dev-framework dependency is cloned from a pinned tag. SBOM generation either succeeds or fails the build. DAST for web is blocking. Branch protection is documented with copy-pasteable `gh api` commands.

The framework explicitly and repeatedly excludes itself from compliance-regulated environments (SOC 2, HIPAA, PCI-DSS, FedRAMP) across five independent documents. It targets internal tools, departmental applications, MVPs, and prototypes. This self-awareness is genuine and consistent.

**Remaining gaps** are structural limitations of the operating model rather than implementation oversights: no technical DLP prevents sensitive data from reaching the LLM API (inherent to all LLM-based tools), branch protection requires manual execution of the provided `gh api` command (not automated by `init.sh`), non-security GitHub Actions still use mutable major-version tags, and all Tier 3 controls depend on LLM behavioral compliance with no mechanical fallback. These are documented, understood, and appropriate for the framework's stated scope.

---

## Threat Model Summary — Top 5 Threats

| # | Threat | Threat Actor | Likelihood | Impact | Framework Mitigation | Effectiveness |
|---|---|---|---|---|---|---|
| **T1** | **Sensitive data exfiltration via LLM API** — Source code, credentials, PII, or proprietary logic transmitted to Anthropic's servers | Passive (Anthropic as data processor) or active (compromised API endpoint) | High (inherent) | Critical | Governance framework requires IT Security approval of AI deployment path. Expanded `.gitignore` excludes common secret patterns. CLAUDE.md instructs against credentials in prompts. No technical DLP. | **Moderate** — Meaningful organizational control without technical enforcement. Inherent limitation of the operating model. |
| **T2** | **Circular validation** — AI generates both tests and implementation; tests validate AI behavior rather than specifications | The AI itself (systemic) | High (inherent) | High | Orchestrator writes ≥3 assertions per feature. Superpowers TDD skill enforces RED-GREEN-REFACTOR. Pre-commit hook warns on missing tests. Red-team evaluation prompt identifies this risk. | **Moderate** — Multiple procedural mitigations with soft enforcement. No mechanism verifies human authorship of assertions. |
| **T3** | **Supply chain compromise via GitHub Actions** — Malicious update to a CI action | Attacker who compromises an Action repository | Low | Critical | Security-critical actions (semgrep, gitleaks, osv-scanner) pinned to commit SHAs. Non-security actions use major-version tags. | **Strong for security actions** — SHA pins eliminate tag-mutation attacks for the three most critical actions. Residual risk limited to convenience actions (checkout, setup-node). |
| **T4** | **Pre-commit hook bypass** — `--no-verify` skips local gitleaks + Semgrep checks | Negligent developer | Medium | Low (mitigated) | **Three-layer defense**: Pre-commit gitleaks + Semgrep (bypassable), CI gitleaks-action (not bypassable), CI Semgrep (not bypassable). All blocking. | **Strong** — Defense-in-depth is genuine. Both pre-commit checks have CI backstops. Secrets and OWASP findings require bypassing two independent layers. |
| **T5** | **Branch protection not auto-configured** — Direct commits to main bypass CI | The Orchestrator (accidentally) | Medium | Medium | Builder's Guide provides copy-pasteable `gh api` command. Not executed by `init.sh`. Post-init instructions reference it. | **Moderate** — Better than documentation alone (command is ready to run), but requires human action. Solo-developer context limits adversarial risk. |

---

## Phase 2: Detailed Security Assessment

---

### Category 1: Attack Surface Analysis

**Finding 1.1: Security-critical GitHub Actions are pinned to commit SHAs.**

- **Files:** All 8 CI templates
- **Observation:** `semgrep/semgrep-action@713efdd345f3035192eaa63f56867b88e63e4e5d` (v0.58.0), `gitleaks/gitleaks-action@ff98106e4c7b2bc287b24eaf42907196329070c7` (v2.3.9), `google/osv-scanner-action@c51854704019a247608d928f370c98740469d4b5` (v2.3.5). The SHA and corresponding version are documented in inline comments for maintainability.
- **Severity:** Informational (positive finding)
- **Assessment:** This is the gold standard for CI supply chain security. Tag-mutation attacks against these three security-critical actions are eliminated. Non-security actions (`actions/checkout@v4`, `actions/setup-node@v4`, etc.) still use major-version tags, which is a reasonable trade-off — these are first-party GitHub actions with stronger security controls.

**Finding 1.2: The claude-dev-framework clone is pinned to a tag.**

- **File:** `init.sh`, line 286: `git clone -q --branch v1.0 --depth 1`
- **Observation:** Clone targets `v1.0` tag with shallow depth. SHA is captured and recorded. Nested `.git` removed for self-containment.
- **Severity:** Low (residual risk — tags are mutable, but combined with SHA recording this is reasonable)

**Finding 1.3: No runtime binary downloads in CI templates.**

- **Observation:** All CI templates use GitHub Actions or language package managers for tool installation. No `curl | bash` patterns, no unsigned binary downloads.
- **Severity:** Informational (positive finding)

**Finding 1.4: Non-security GitHub Actions use major-version tags.**

- **Observation:** `actions/checkout@v4`, `actions/setup-node@v4`, `actions/setup-python@v5`, `actions/setup-go@v5`, `actions/upload-artifact@v4`, `softprops/action-gh-release@v2`, etc. These are convenience/setup actions, not security enforcement actions.
- **Severity:** Low — These are first-party GitHub actions or widely-used community actions. The risk/maintenance trade-off of SHA-pinning every action is not justified for non-security-critical steps.

---

### Category 2: LLM Security Boundary Analysis

**Finding 2.1: No technical DLP prevents sensitive data from being sent to the LLM.**

- **Observation:** The governance framework requires IT Security approval of the AI deployment path. The `.gitignore` includes an expanded set of secret patterns (`.env`, `credentials.json`, `service-account.json`, `terraform.tfvars`, `.npmrc`, `*.pfx`, `*.keystore`, etc.). CLAUDE.md instructs against credentials in prompts. No technical filtering or redaction mechanism exists.
- **Severity:** Medium
- **Assessment:** This is a structural limitation of LLM-based development tools, not a framework-specific deficiency. The framework's mitigations (deployment path approval, `.gitignore`, LLM instructions) are the maximum currently feasible without platform-level support from Claude Code. A `.claudeignore` mechanism would be valuable if Claude Code adds support.

**Finding 2.2: Prompt injection through project files is unmitigated at the framework level.**

- **Severity:** Medium (industry-wide limitation)
- **Assessment:** Defense against prompt injection is the LLM provider's responsibility. The framework's mobile platform module includes specific guidance on prompt injection mitigation for features in the built application, demonstrating awareness.

---

### Category 3: Enforcement vs. Theater

#### Security Controls Classification Matrix

| # | Security Claim | Classification | Evidence |
|---|---|---|---|
| 1 | **SAST scanning (Semgrep, CI)** | **Enforced** | `semgrep/semgrep-action` (SHA-pinned) with `p/owasp-top-ten` + `p/security-audit` in all 8 CI templates. Blocking. |
| 2 | **SAST scanning (Semgrep, pre-commit)** | **Enforced (Tier 2)** | Pre-commit hook runs `semgrep scan --config=p/owasp-top-ten` on staged files. Blocking. Bypassable with `--no-verify`; CI backstop catches it. |
| 3 | **Secret detection (CI)** | **Enforced** | `gitleaks/gitleaks-action` (SHA-pinned) in all 8 CI templates. Blocking. |
| 4 | **Secret detection (pre-commit)** | **Enforced (Tier 2)** | Pre-commit hook runs `gitleaks protect --staged`. Blocking. Bypassable with `--no-verify`; CI backstop catches it. |
| 5 | **Dependency vulnerability audit** | **Enforced** | Language-specific tools in all 8 CI templates. All blocking. `other.yml` uses `exit 1` placeholder. |
| 6 | **License compliance** | **Enforced** | All 8 templates block on copyleft. Python now catches GPL-2.0, GPL-3.0, and AGPL-3.0 (parity with other languages). |
| 7 | **SBOM generation (web)** | **Enforced** | CycloneDX in web release. No `continue-on-error`. |
| 8 | **SBOM generation (desktop/CLI)** | **Enforced (blocks until configured)** | `exit 1` placeholder forces configuration. |
| 9 | **SBOM generation (mobile)** | **Advisory** | Commented out with `continue-on-error: true`. |
| 10 | **DAST (web)** | **Enforced** | ZAP baseline in web release pipeline. No `continue-on-error`. |
| 11 | **DAST (desktop/mobile/CLI)** | **Not Active** | Commented out or absent. Appropriate for non-web platforms. |
| 12 | **TDD enforcement** | **Advisory (Tier 3) with soft enforcement (Tier 2)** | Pre-commit warns on missing test files. Superpowers TDD skill encourages RED-GREEN-REFACTOR. CI verifies tests pass. |
| 13 | **Phase gate tracking** | **Partially Enforced** | `.claude/phase-state.json` tracks state. `check-phase-gate.sh` runs in CI (warns, does not block). |
| 14 | **Branch protection** | **Documented with ready-to-run command** | Builder's Guide (line 713) provides `gh api` command. Not auto-executed by `init.sh`. |
| 15 | **Approval log integrity** | **Partially Enforced** | Phase gate check cross-references dates. Git history provides audit trail. |
| 16 | **Dependency pinning** | **Partially Enforced** | TypeScript has lockfile integrity check. Other languages rely on lockfile presence. |
| 17 | **DLP for AI prompts** | **Not Present** | Acknowledged structural limitation. |
| 18 | **Credential rotation** | **Advisory** | Documented cadences, no automation. |
| 19 | **Test co-location** | **Advisory (Tier 2, non-blocking)** | Pre-commit warns. Does not block commit. |
| 20 | **Competency matrix enforcement** | **Partially Enforced** | `validate.sh` checks competency matrix against CI tools. Phase 1→2 gate verifier checks. |
| 21 | **Code signing** | **Not Implemented** | TODO stubs in release pipelines. |
| 22 | **Lockfile integrity** | **Enforced (TypeScript only)** | `npm audit signatures`. No equivalent for other languages. |

**Framework security posture if the LLM ignores 100% of Tier 3 controls:**

Remaining mechanical enforcement:
- SAST: Semgrep with `p/owasp-top-ten` + `p/security-audit` on every push (CI) AND every commit (pre-commit) — two layers, both blocking
- Secrets: gitleaks on every push (CI) AND every commit (pre-commit) — two layers, both blocking
- Dependencies: Language-specific audit on every push — blocking
- Licenses: Language-specific check on every push — blocking (all languages at parity)
- SBOM: Generates or fails (web, desktop, CLI) — blocking
- DAST: ZAP baseline on web release — blocking
- Phase gates: CI warns on inconsistencies
- Test co-location: Pre-commit warns on missing tests

This is a robust security baseline that operates entirely without LLM cooperation. It exceeds what most individual-developer projects implement.

**Does the framework create a false sense of security?** No. The User Guide (lines 47-82) contains a complete three-tier breakdown table that classifies every control. The distinction between "mechanically enforced," "partially enforced (bypassable)," and "guided (LLM instructions)" is explicit and prominent.

---

### Category 3 (continued): Defense Chain Map

| Security Concern | Tier 1: CI (Hard) | Tier 2: Hooks (Early) | Tier 3: Rules (Guided) | Coverage |
|---|---|---|---|---|
| **Secret detection** | gitleaks-action SHA-pinned — **BLOCKS** | gitleaks pre-commit — **BLOCKS** | CLAUDE.md "do not commit secrets" | **Redundant (Multi-Layer)** — Two independent blocking layers |
| **SAST / vulnerability patterns** | Semgrep SHA-pinned, `p/owasp-top-ten` + `p/security-audit` — **BLOCKS** | Semgrep pre-commit, `p/owasp-top-ten` staged files — **BLOCKS** | CLAUDE.md "Never Do This" list | **Redundant (Multi-Layer)** — Two independent blocking layers. Pre-commit is fast/staged; CI is comprehensive. |
| **Dependency vulnerabilities** | Language-specific audit — **BLOCKS** | Not present | Builder's Guide "pin dependencies" | **Single Mechanical Layer** — CI audit is robust across all 8 languages |
| **License compliance** | Language-specific checker — **BLOCKS** | Not present | Not in CLAUDE.md | **Single Mechanical Layer** — All languages at parity (GPL-2.0, GPL-3.0, AGPL-3.0) |
| **TDD enforcement** | CI verifies tests pass | Pre-commit warns on missing tests | CLAUDE.md "test-first", Superpowers TDD | **Advisory with Soft Enforcement** |
| **DAST (web)** | ZAP baseline — **BLOCKS** release | Not present | Phase 3 checklist | **Single Mechanical Layer** |
| **SBOM accuracy** | CycloneDX or `exit 1` — **BLOCKS** | Not present | Phase 4 checklist | **Single Mechanical Layer** — No empty fallbacks |
| **Code signing** | TODO stubs | Not present | Not present | **Not Implemented** |
| **DLP for AI prompts** | Not present | Not present | CLAUDE.md "no PII/credentials" | **Advisory Only** — Structural limitation |
| **Branch protection** | Not auto-configured | Not present | `gh api` command in Builder's Guide | **Documented (not automated)** |
| **Phase gate consistency** | check-phase-gate.sh — **WARNS** | Not present | CLAUDE.md instructions | **Advisory with Soft Enforcement** |

**Defense Chain Assessment:** The framework achieves genuine defense-in-depth for its two highest-risk attack vectors: secrets and SAST findings. Both have two independent mechanical layers (pre-commit + CI), both blocking, with CI using SHA-pinned actions. Dependency auditing and license compliance have single but robust mechanical layers with consistent enforcement across all supported languages. The remaining gaps (code signing, DLP, branch protection automation) are documented, understood, and appropriate for the framework's stated scope.

---

### Category 4: Secrets and Sensitive Data Handling

**Finding 4.1: Secret detection has three-layer defense-in-depth.**

- Layer 1: Pre-commit gitleaks (blocking, bypassable with `--no-verify`)
- Layer 2: Pre-commit Semgrep OWASP scan catches some hardcoded credential patterns (blocking, same bypass risk)
- Layer 3: CI gitleaks-action SHA-pinned (blocking, not bypassable without skipping CI entirely)
- **Assessment:** This is strong. Secrets can only reach the remote repository if the developer bypasses both pre-commit hooks AND pushes without a PR that triggers CI.

**Finding 4.2: Comprehensive `.gitignore` template.**

- Covers: `.env*`, `*.pem`, `*.key`, `*.p12`, `*.jks`, `*.pfx`, `*.keystore`, `credentials.json`, `service-account.json`, `terraform.tfvars`, `terraform.tfvars.json`, `.npmrc`, plus platform and language-specific patterns.
- **Assessment:** Comprehensive coverage of common secret file patterns.

---

### Category 5: Compliance Framework Compatibility

| Framework | Assessment |
|---|---|
| **PCI-DSS** | **Not Appropriate (by design)** — Explicitly excluded. Single-person model violates separation of duties. |
| **HIPAA** | **Not Appropriate (by design)** — Explicitly excluded. No PHI safeguards. |
| **SOC 2 Type II** | **Not Appropriate (by design)** — Explicitly excluded. Advisory controls insufficient for audit. |
| **SOX (ITGC)** | **Not Appropriate (by design)** — Intake screens for applicability. Single-person model is material weakness. |
| **FedRAMP** | **Not Appropriate (by design)** — Explicitly excluded. Negligible NIST 800-53 coverage. |

The framework explicitly excludes all five compliance frameworks across multiple documents with consistent language. The Intake Template includes compliance screening (Section 8.4) that identifies when projects drift into compliance scope.

---

### Category 6: Supply Chain Security

| Dependency | Source | Integrity | Risk |
|---|---|---|---|
| semgrep/semgrep-action | GitHub Actions | **SHA-pinned** | **Low** |
| gitleaks/gitleaks-action | GitHub Actions | **SHA-pinned** | **Low** |
| google/osv-scanner-action | GitHub Actions | **SHA-pinned** | **Low** |
| actions/checkout | GitHub Actions (1st party) | Major-version tag | Low |
| actions/setup-* | GitHub Actions (1st party) | Major-version tag | Low |
| claude-dev-framework | GitHub clone | Pinned tag + SHA recorded | Low-Medium |
| Semgrep, gitleaks, Snyk | Package managers | Package manager verification | Low |
| CycloneDX, ZAP | npm/Docker | Package manager / Docker trust | Low |

**Assessment:** Security-critical dependencies are SHA-pinned. Non-security dependencies use standard versioning. No unsigned binary downloads. Supply chain posture is strong for a framework of this type.

---

### Category 7: Incident Response Implications

**Positive findings:**
- Phase state tracking (`.claude/phase-state.json`) provides temporal traceability of project progression
- Approval log with structured entries provides governance audit trail
- `validate.sh` enables on-demand compliance verification
- `check-updates.sh` enables drift detection against upstream
- Self-contained project architecture bounds blast radius of framework flaws
- SBOM attached to GitHub releases provides software inventory

**Gap:** No LLM interaction logging. This is a Claude Code platform limitation, not a framework gap.

---

### Category 8: Secure Development Lifecycle Integration

**Finding 8.1: Semgrep uses targeted security rulesets.**

- **Observation:** All CI templates use `config: p/owasp-top-ten` + `p/security-audit`. The pre-commit hook uses `p/owasp-top-ten` for fast staged-file scanning. This is a significant upgrade from `--config=auto` — it targets known vulnerability patterns rather than relying on generic heuristics.
- **Severity:** Informational (positive finding)

**Finding 8.2: OWASP Top 10 coverage assessment.**

| OWASP Top 10 (2021) | Coverage | Mechanism | Tier |
|---|---|---|---|
| A01: Broken Access Control | Advisory | Threat model, CLAUDE.md | 3 |
| A02: Cryptographic Failures | **Detected** | Semgrep `p/owasp-top-ten` | 1+2 |
| A03: Injection | **Detected** | Semgrep `p/owasp-top-ten` | 1+2 |
| A04: Insecure Design | Advisory | Threat model | 3 |
| A05: Security Misconfiguration | Partial (web) | ZAP baseline + Semgrep `p/security-audit` | 1 (web) / 3 (other) |
| A06: Vulnerable Components | **Enforced** | Dependency audit all languages | 1 |
| A07: Auth Failures | **Detected** | Semgrep `p/owasp-top-ten` | 1+2 |
| A08: Software/Data Integrity | Partial | Lockfile check (TS), SBOM, SHA-pinned actions | 1 (partial) |
| A09: Logging/Monitoring Failures | Advisory | Structured logging requirement | 3 |
| A10: SSRF | **Detected** | Semgrep `p/owasp-top-ten` | 1+2 |

The targeted Semgrep rulesets provide mechanical detection for 5 of the OWASP Top 10 categories (A02, A03, A05, A07, A10) at both pre-commit and CI levels.

---

### Category 9: Additional Observations

**Finding 9.1: The pre-commit hook now has three enforcement checks.**

- **File:** `init.sh`, lines 398-503
- **Observation:** The mechanically-installed pre-commit hook includes: (1) gitleaks secret detection — **blocking**, (2) Semgrep OWASP Top 10 scan on staged files — **blocking**, (3) test co-location check — **warning**. Both blocking checks have CI backstops.
- **Assessment:** This is a well-layered local enforcement mechanism. Developers get immediate security feedback on commit without waiting for CI.

**Finding 9.2: Branch protection has a copy-pasteable `gh api` command.**

- **File:** `docs/builders-guide.md`, lines 709-727
- **Observation:** A complete `gh api` command is provided that configures: PRs required, status checks required, stale review dismissal, force pushes disabled, rules apply to admins. Manual UI instructions are provided as a fallback.
- **Assessment:** This is practical and appropriate. The command is not auto-executed by `init.sh` because it requires the repository to exist on GitHub with an initial push first (chicken-and-egg problem). The documentation makes execution straightforward.

**Finding 9.3: Python license compliance is at parity with other languages.**

- **File:** `templates/pipelines/ci/python.yml`, line 48
- **Observation:** `pip-licenses --fail-on="GNU General Public License v2 (GPLv2);GNU General Public License v3 (GPLv3);GNU Affero General Public License v3 (AGPLv3)"` — catches all three copyleft variants, matching TypeScript, Rust, Go, C#, and Dart.
- **Severity:** Informational (positive finding — previously this was a gap)

**Finding 9.4: JVM linting remains advisory.**

- **File:** `templates/pipelines/ci/jvm.yml`, line 30
- **Observation:** `continue-on-error: true` on detekt. This is documented as requiring a Gradle plugin that may not be installed.
- **Severity:** Low — Linting is a code quality control. Security-relevant JVM checks (SAST, dependency audit, license compliance, secret detection) are all blocking.

**Finding 9.5: Mobile SBOM remains advisory when uncommented.**

- **File:** `templates/pipelines/release/mobile.yml`, line 329
- **Observation:** SBOM section is commented out with `continue-on-error: true`.
- **Severity:** Low — Mobile apps distributed through app stores are subject to store-level security review. The SBOM gap is less critical than for self-distributed platforms (web, desktop, CLI) where SBOMs are blocking.

---

## Hard Stops

1. **PCI-DSS cardholder data environments** — Explicitly excluded. Separation of duties violation.
2. **HIPAA Protected Health Information** — Explicitly excluded. No technical safeguards.
3. **SOC 2 Type II scope** — Explicitly excluded. Advisory controls insufficient.
4. **FedRAMP authorization scope** — Explicitly excluded. Negligible NIST 800-53 coverage.
5. **ITAR/EAR controlled information** — LLM data transmission incompatible.
6. **99.99%+ SLA systems** — Single-maintainer model incompatible.
7. **Environments where AI provider terms have not been approved by legal** for the applicable data classification.

---

## Minimum Viable Security Assessment

The framework's mechanical enforcement layer addresses all critical and high-severity items that are within its control:

| Requirement | Status |
|---|---|
| Secret detection in CI (defense-in-depth) | **Implemented** — gitleaks pre-commit + CI, both blocking |
| SAST in CI with security-focused rulesets | **Implemented** — Semgrep with `p/owasp-top-ten` + `p/security-audit`, pre-commit + CI |
| Security-critical actions SHA-pinned | **Implemented** — semgrep, gitleaks, osv-scanner |
| Dependency auditing all languages | **Implemented** — All 8 templates, all blocking |
| License compliance all languages | **Implemented** — All 8 templates at parity |
| SBOM integrity (no empty artifacts) | **Implemented** — Succeeds or fails (web/desktop/CLI) |
| DAST blocking for web | **Implemented** — ZAP baseline, no continue-on-error |
| Framework dependency pinned | **Implemented** — `--branch v1.0` with SHA recorded |
| Pre-commit hook mechanically installed | **Implemented** — gitleaks + Semgrep + test check |
| Branch protection documented with executable command | **Implemented** — `gh api` command in Builder's Guide |
| Python license check at parity | **Implemented** — GPLv2 + GPLv3 + AGPLv3 |
| No unsigned binary downloads in CI | **Implemented** — Official actions and package managers only |

**Remaining recommendations (informational, not blocking):**

1. **Automate branch protection setup.** The `gh api` command could be added as a post-init step that runs if `gh` is authenticated and the remote is configured. Currently requires manual execution.

2. **Monitor Claude Code for `.claudeignore` support.** A file-exclusion mechanism for LLM context would address the DLP gap at the platform level.

3. **Consider SHA-pinning `softprops/action-gh-release@v2`.** This action has `contents: write` permission in all release pipelines. While not a security scanning action, its elevated permissions make it higher-risk than setup actions.

4. **Mobile SBOM:** For apps not distributed through app stores, consider making SBOM blocking rather than advisory.

---

## Overall Security Rating

### **APPROVED** — For Stated Scope

**Justification:**

The Solo Orchestrator Framework provides a security posture that **exceeds what the vast majority of individual-developer projects implement** and is **appropriate and sufficient for its stated scope** (internal tools, departmental applications, prototypes, and MVPs handling non-regulated data).

The framework earns an Approved rating (upgraded from the conditional rating that would apply to a less mature implementation) based on:

**Mechanical enforcement is comprehensive for its scope:**
- Secret detection: Two independent blocking layers (pre-commit + CI), both with SHA-pinned tooling
- SAST: Two independent blocking layers with targeted OWASP Top 10 + security audit rulesets
- Dependency auditing: Blocking across all 8 supported languages
- License compliance: Blocking across all 8 languages at full copyleft parity
- SBOM: Generates or fails (no empty artifacts) for web, desktop, CLI
- DAST: Blocking for web releases
- Supply chain: Security-critical actions SHA-pinned

**Transparency is genuine:**
- Three-tier enforcement model explicitly documented with user-facing classification table
- Every control classified as enforced, partially enforced, or advisory
- Scope exclusions stated in 5+ documents with consistent language
- Red-team evaluation prompt invites scrutiny of the framework's own weaknesses
- `validate.sh` enables on-demand compliance verification

**Remaining gaps are structural, documented, and appropriate:**
- No technical DLP for LLM prompts (inherent to all LLM development tools)
- Branch protection requires manual `gh api` execution (documented with command)
- Tier 3 controls depend on LLM compliance (explicitly documented as such)
- Code signing not implemented (documented as TODO, appropriate for internal tools)

**Conditions of this approval:**

1. Used only within stated scope (non-regulated data, no compliance certification requirements).
2. AI deployment path explicitly approved by IT Security before company source code is processed.
3. The framework supplements, not replaces, existing organizational AppSec programs.
4. Applications that drift into compliance scope must be re-evaluated under the appropriate framework.
5. The `gh api` branch protection command in the Builder's Guide must be executed after initial repository push — this is the one manual security step that should not be skipped.

---

*This assessment was performed as a fresh, read-only review. No code was executed, no vulnerabilities were tested, and no framework files were modified.*

---

**Document Control**

| Field | Value |
|---|---|
| **Document ID** | SECURITY-REVIEW-001 |
| **Version** | 3.0 |
| **Date** | 2026-04-02 |
| **Classification** | Confidential |
| **Reviewer** | SVP, IT Security |
| **Scope** | Solo Orchestrator Framework v1.0 (all files) |
| **Next Review** | Upon framework update or before organizational deployment |
