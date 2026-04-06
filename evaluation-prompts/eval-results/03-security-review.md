# Solo Orchestrator Framework -- Security Review

**Reviewer Persona:** Senior VP of IT Security (20+ years: AppSec, infrastructure security, compliance, risk management)
**Framework Version:** 1.0
**Review Date:** 2026-04-05
**Classification:** Security Assessment -- READ-ONLY

---

## Security Executive Summary

The Solo Orchestrator Framework provides a structured development methodology with a layered security control architecture that is honestly documented and meaningfully implemented for its stated scope (internal tools, MVPs, non-regulated environments). The framework's primary security value resides in its Tier 1 CI pipeline, which mechanically enforces SAST scanning (Semgrep), secret detection (gitleaks), dependency vulnerability auditing, and license compliance checks as hard gates that block merges on failure. The Tier 2 pre-commit hooks provide genuine defense-in-depth for secret detection and OWASP Top 10 findings at commit time, with the CI pipeline serving as a backstop if hooks are bypassed. The framework is transparent -- repeatedly and explicitly -- about which controls are mechanically enforced versus advisory, which is a security-positive design choice that prevents false confidence. Critical gaps exist in framework integrity verification (no cryptographic signatures on templates or scripts), the use of `eval` for tool installation commands sourced from JSON configuration, and the absence of any mechanical control preventing deployment in regulated environments. The framework is appropriate for its stated scope with specific remediations, and must not be used for systems handling PII, PHI, financial data, or operating under compliance mandates without substantial hardening.

---

## Threat Model Summary -- Top 5 Threats

| # | Threat | Actor | Likelihood | Impact | Current Mitigation |
|---|---|---|---|---|---|
| 1 | **Supply chain compromise of the solo-orchestrator or claude-dev-framework repository** | External attacker compromising GitHub account or performing dependency confusion | Medium | Critical -- all downstream projects inherit malicious code via init.sh | No integrity verification (no checksums, no signatures, no pinned commits for claude-dev-framework clone). Framework version is tracked post-init but not verified against a signed manifest. |
| 2 | **Arbitrary command execution via tool-matrix JSON injection** | Attacker who compromises tool-matrix JSON files or tool-preferences.json | Medium | Critical -- `resolve-tools.sh` (line 208), `check-versions.sh` (line 198), `check-phase-gate.sh` (line 173), and `verify-install.sh` (line 670) all use `eval` on `check_command`, `version_command`, and `install_cmd` values from JSON | JSON files are shipped with the framework and copied locally, but user-editable `tool-preferences.json` feeds directly into eval-based execution. |
| 3 | **LLM generating vulnerable code patterns that bypass advisory controls** | LLM producing code with injection flaws, broken auth, or insecure defaults | High (LLMs regularly produce vulnerable code) | Medium-High -- depends on what the generated application does | Tier 1 CI catches OWASP Top 10 patterns via Semgrep. Tier 2 pre-commit also scans. But Semgrep catches known patterns, not novel logic flaws. No DAST during development (only in release pipeline). |
| 4 | **Scope creep into regulated environments without detection** | Well-meaning operator deploying a Solo Orchestrator app for a use case involving PII, PHI, or financial data | High (no mechanical barrier) | Critical -- compliance violations, breach exposure | Documentation clearly states the exclusion. Intake Section 8 has a compliance screening matrix. But nothing mechanically prevents deployment -- it is purely advisory. |
| 5 | **Secret exposure through LLM context window** | All project files, including those potentially containing secrets, are read by the LLM | Medium | High -- API keys, tokens, database credentials sent to Anthropic API | `.gitignore` template excludes `.env`, `*.pem`, `*.key`, `credentials.json`. Claude Code permissions deny `Read(./.env)` and `Read(./.env.*)`. Pre-commit gitleaks catches staged secrets. But nothing prevents the LLM from reading secrets in non-standard locations or in code files during a session. |

---

## Category 1: Attack Surface Analysis

### Finding

The framework introduces several attack surfaces to the development environment:

**1.1 Template Repository as Single Point of Trust.** `init.sh` (line 1249) clones `https://github.com/kraulerson/claude-dev-framework.git` with `--depth 1` into `~/.claude-dev-framework`. No commit SHA verification, no GPG signature check, no checksum validation. The `check-updates.sh` script (line 30) also clones the main solo-orchestrator repo to a temp directory for comparison with no integrity checks. A compromised GitHub account or man-in-the-middle on the clone could inject malicious hooks, scripts, or CI templates into every downstream project.

**1.2 eval-based Command Execution from JSON.** Multiple scripts use `eval` to execute commands sourced from JSON files:
- `resolve-tools.sh` line 208: `eval "$TOOL_CHECK"` where `TOOL_CHECK` comes from `check_command` in tool-matrix JSON
- `resolve-tools.sh` line 213: `eval "$TOOL_VERSION_CMD"` from `version_command`
- `check-versions.sh` line 198: `eval "$CHECK_CMD"` from tool-matrix JSON
- `check-versions.sh` line 206: `eval "$INSTALLED"` from `version_command`
- `check-versions.sh` line 308/330: `eval "$cmd"` from install commands
- `check-phase-gate.sh` line 173: `eval "$cmd"` from auto-install commands
- `verify-install.sh` line 670: `eval "$install_cmd"` from resolver output
- `init.sh` line 752: `eval "$tool_cmd"` for auto-install commands
- `scripts/lib/helpers.sh` line 158: `eval "$install_cmd"` in `prompt_install`
- `resolve-tools.sh` line 48: `eval val="\$$var_name"` for argument validation

The tool-matrix JSON files (`templates/tool-matrix/common.json`, `web.json`, `desktop.json`, `mobile.json`) ship with the framework, so the baseline commands are author-controlled. However, `tool-preferences.json` is user-editable and its `additions` array feeds `check_command` values directly into eval (resolve-tools.sh lines 270-271). A compromised or maliciously crafted `tool-preferences.json` achieves arbitrary code execution.

**1.3 Pre-commit Hook as Code Injection Vector.** The pre-commit hook is generated by `init.sh` (lines 1529-1648) and written to `.git/hooks/pre-commit`. If the framework repository is compromised, the hook template injects code that runs on every commit. The Development Guardrails framework (`claude-dev-framework`) also installs hooks -- its `init.sh` is executed with full shell privileges from the project directory (init.sh line 1329-1330).

**1.4 Script Execution with Broad Permissions.** The generated `.claude/settings.json` (init.sh lines 1166-1225) grants the LLM permission to execute `Bash(bash scripts/*)`, which means the LLM can invoke any script in the project's `scripts/` directory. If a script is maliciously modified or a new script is placed there, the LLM can execute it.

### Threat Model
- **Actor:** External attacker compromising upstream repos; insider modifying JSON configs; supply chain compromise of claude-dev-framework
- **Attack path:** Compromise GitHub repo -> all new projects inherit malicious templates/hooks/scripts. Or: modify tool-preferences.json -> eval executes arbitrary commands on next tool resolution.

### Severity: High

### Exploitability
- Supply chain: Requires compromising a GitHub account -- moderate difficulty but high-value target given all downstream projects are affected.
- JSON injection via eval: Requires write access to `.claude/tool-preferences.json` -- local file, so requires prior local access. But the `additions` array is designed to be user-edited, and users may not understand they are providing shell commands.

### Remediation
1. **Critical:** Pin the `claude-dev-framework` clone to a specific commit SHA stored in the framework and verified post-clone. Add `git verify-commit` if the upstream repo signs commits.
2. **Critical:** Replace all `eval "$cmd"` patterns with a whitelist-based command executor that validates commands against known-safe patterns before execution. At minimum, sanitize inputs or use a restricted command dispatch.
3. **High:** Add SHA256 checksums for all template files in a manifest, verified by `init.sh` and `check-updates.sh`.
4. **Medium:** Restrict `.claude/settings.json` `Bash(bash scripts/*)` to enumerate specific script names rather than a wildcard.

---

## Category 2: LLM Security Boundary Analysis

### Finding

**2.1 No Prompt Injection Prevention.** The framework sends the entire project context (CLAUDE.md, PROJECT_INTAKE.md, Builder's Guide, Project Bible, source code) to the LLM. If any project file contains adversarial content (e.g., a dependency's README with prompt injection instructions, or a user-submitted issue body with embedded instructions), the LLM may follow those instructions. There is no sanitization layer between project files and LLM context. This is inherent to the LLM operating model and not unique to this framework, but the framework does not document or mitigate it.

**2.2 Sensitive Data Exposure to LLM API.** The framework instructs the LLM to read all project files. The `.claude/settings.json` deny rules (init.sh lines 1216-1221) block reading `.env` and `.env.*` files, which is a genuine mechanical control. The `.gitignore` template (`templates/generated/gitignore-base.tmpl` lines 8-11) excludes `.env`, `*.pem`, `*.key`, `credentials.json`, and `service-account.json`. However:
- Secrets hardcoded in source files (not in `.env`) are readable by the LLM
- Database connection strings in config files not matching the deny patterns are readable
- The deny rules use exact path patterns -- `Read(./.env)` -- which would not match nested paths like `./config/.env` or `./services/api/.env`

**2.3 No Mechanism to Prevent LLM from Generating Vulnerable Patterns.** The CLAUDE.md template (lines 47-53) instructs the agent to follow TDD and security practices. Semgrep in CI and pre-commit catches OWASP Top 10 patterns. But the LLM can generate code with logic flaws (broken access control, IDOR, race conditions, business logic bypasses) that do not match Semgrep patterns. The framework relies on the Orchestrator's code review at decision gates -- this is honestly documented but is not a security control.

**2.4 Data Residency and Retention.** All project context sent to the Anthropic API is subject to Anthropic's data retention policies. The framework does not document data residency implications. For organizational deployments handling internal business data (even non-regulated), this may conflict with data handling policies. The governance framework (Section V) requires IT Security approval of the "AI deployment path" including "commercial terms, data handling" before Phase 0, which is the correct procedural control, but there is no technical enforcement.

### Threat Model
- **Actor:** Adversarial content in dependencies or user input; LLM generating vulnerable code; data exposure to third-party API
- **Attack path:** Prompt injection via project files; LLM generates IDOR/race condition not caught by SAST; secrets in non-standard locations sent to API

### Severity: Medium (for stated scope of internal tools/MVPs)

### Exploitability
- Prompt injection: Moderate -- requires adversarial content in a file the LLM reads, but this could come from a compromised dependency's README or changelog.
- Vulnerable code generation: High -- LLMs regularly generate code with logic flaws that SAST does not catch.
- Data exposure: Low for internal tools with no PII; High if scope creep occurs.

### Remediation
1. **High:** Document prompt injection risk explicitly in the security model. Add guidance on reviewing dependency documentation for adversarial content.
2. **Medium:** Expand the `.env` deny patterns to cover nested paths: `Read(**/.env)`, `Read(**/.env.*)`.
3. **Medium:** Add data residency and API data handling documentation to the governance framework, with a checklist for IT Security review.
4. **Low:** Document the classes of vulnerabilities that Semgrep will NOT catch (logic flaws, IDOR, race conditions, business logic) and emphasize the Orchestrator's review responsibility for those categories.

---

## Category 3: Enforcement vs. Theater

### Defense Chain Map

For each security-relevant concern, the following maps which enforcement layers provide coverage:

| Security Concern | Tier 1 (CI Pipeline) | Tier 2 (Pre-commit Hooks) | Tier 3 (CLAUDE.md / Docs) | Redundant Coverage? | Mechanical Enforcement? |
|---|---|---|---|---|---|
| **Secret detection** | gitleaks-action (blocks PR) | gitleaks protect --staged (blocks commit) | CLAUDE.md deny rules for .env reads | YES -- 3 layers, 2 mechanical | YES |
| **SAST (OWASP Top 10)** | semgrep-action (blocks PR) | semgrep scan --config=p/owasp-top-ten (blocks commit) | CLAUDE.md instructs security audits per feature | YES -- 3 layers, 2 mechanical | YES |
| **Dependency vulnerabilities** | npm audit / pip-audit / cargo audit etc. (blocks PR) | None | CLAUDE.md instructs pinned dependencies | Partial -- 1 mechanical layer | YES (CI only) |
| **License compliance** | license-checker / pip-licenses with --failOn (blocks PR) | None | None | NO -- single mechanical layer | YES (CI only) |
| **Tests must pass** | CI step (blocks PR) | None | CLAUDE.md instructs TDD | Partial -- 1 mechanical layer | YES (CI only) |
| **Build must succeed** | CI step (blocks PR) | None | None | NO -- single mechanical layer | YES (CI only) |
| **Phase gate consistency** | check-phase-gate.sh in CI (blocks PR; downgrade via SOIF_PHASE_GATES=warn) | None | CLAUDE.md instructs phase awareness | Partial -- 1 mechanical layer, bypassable via env var | PARTIAL |
| **TDD ordering** | None | Pre-commit hook warns (does NOT block) | CLAUDE.md instructs test-first; Superpowers plugin encourages | NO mechanical enforcement | NO -- warning only |
| **Schema migration discipline** | None | Pre-commit hook warns (does NOT block) | CLAUDE.md instructs versioned migrations | NO mechanical enforcement | NO -- warning only |
| **Changelog freshness** | CI warns (annotation only; strict mode available) | None | None | NO -- warning unless SOIF_STRICT_CHANGELOG=true | OPTIONAL |
| **Session state freshness** | CI warns (annotation only; strict mode available) | None | None | NO -- warning unless SOIF_STRICT_SESSION=true | OPTIONAL |
| **Test-fix-verify loop** | None | None | CLAUDE.md instructs; test-gate.sh is a manual checkpoint (not CI-integrated) | NO mechanical enforcement | NO -- advisory |
| **Phase gate approval integrity** | None (CI checks date presence, not approver identity) | None | Governance framework says approver must commit, not orchestrator | NO mechanical enforcement for who approves | NO -- policy only |
| **No deployment in regulated environments** | None | None | Documentation states exclusion; Intake Section 8 has compliance screening | NO mechanical enforcement | NO -- advisory |
| **Code review** | None (no branch protection configured by framework) | None | CLAUDE.md instructs review at decision gates | NO mechanical enforcement | NO -- advisory |
| **Lockfile integrity** | npm audit signatures (TypeScript CI only) | None | None | Partial -- only for npm | PARTIAL (language-dependent) |

### Key Finding: Where LLM Non-Compliance Leaves No Backstop

If the LLM ignores 100% of Tier 3 advisory rules, the following still holds mechanically:
- Secrets in staged files are caught (pre-commit + CI)
- OWASP Top 10 SAST findings are caught (pre-commit + CI)
- Dependency vulnerabilities block the merge (CI)
- License violations block the merge (CI)
- Tests must pass (CI)
- Build must compile (CI)

The following is **completely undefended** if the LLM ignores instructions:
- TDD ordering (tests may come after implementation or not at all -- only the test pass/fail gate ensures tests exist at merge time, not that they were written first)
- Phase gate integrity (the LLM could advance phase-state.json without the Orchestrator's approval; CI only checks date presence, not identity)
- Documentation generation (no check that docs are updated)
- Scope control (no check that features match the intake)
- Architecture compliance (no check that code matches the Project Bible)

### Assessment

The framework's security posture with LLM instructions completely ignored is: **functional SAST, secret detection, dependency scanning, license checking, and build/test gates.** This is a meaningful security baseline -- better than the vast majority of solo-developer projects. The honestly documented gap is in process controls (TDD ordering, documentation, scope, architecture compliance), which cannot be mechanically enforced without architectural changes (e.g., a separate linter that checks test-before-implementation commit ordering).

The framework does NOT create a false sense of security. The User Guide (lines 69-100) explicitly documents which controls are mechanically enforced, which are partially enforced, and which are advisory. This is the most security-honest framework documentation I have encountered in this category of tooling.

### Severity: Medium (the honest documentation mitigates the risk of false confidence)

### Exploitability
- Pre-commit hooks are bypassable with `--no-verify`, but CI catches both secrets and SAST as a backstop. This is the correct defense-in-depth pattern.
- Phase gate check can be downgraded via `SOIF_PHASE_GATES=warn` environment variable (check-phase-gate.sh line 255) -- this is documented but creates a bypass path.
- Initial commit uses `--no-verify` (init.sh line 1497) -- documented with justification (template files trigger false positives), but sets a precedent.

### Remediation
1. **High:** Integrate `test-gate.sh --check-phase-gate` as a blocking CI step (currently only called from check-phase-gate.sh when run manually or in CI as a sub-call, but the CI template does not directly invoke the bug gate for Phase 2->3).
2. **Medium:** Add a CI step that verifies git commit author on APPROVAL_LOG.md entries does not match the orchestrator's git identity (enforcing the no-self-approval policy from governance-framework.md line 179-181).
3. **Medium:** Remove the `SOIF_PHASE_GATES=warn` bypass, or require an explicit flag file committed to the repo to enable it (creating an audit trail).
4. **Low:** Add a CI step that checks for the existence of test files when source files are added (enforcing the pre-commit TDD warning as a CI gate).

---

## Category 4: Secrets and Sensitive Data Handling

### Finding

**4.1 Multi-Layer Secret Detection -- Genuine Defense-in-Depth.**
- Pre-commit hook: `gitleaks protect --staged --verbose --no-banner` (init.sh line 1541) -- blocks commit
- CI pipeline: `gitleaks/gitleaks-action@ff98106e4c7b2bc287b24eaf42907196329070c7` pinned to specific commit (typescript.yml line 41) -- blocks PR
- `.gitignore` template: excludes `.env`, `.env.*`, `*.pem`, `*.key`, `*.p12`, `*.jks`, `*.pfx`, `*.keystore`, `credentials.json`, `service-account.json`, `terraform.tfvars`, `.npmrc` (gitignore-base.tmpl lines 8-55)
- Claude Code permissions: deny `Read(./.env)` and `Read(./.env.*)` (init.sh lines 1220-1221)

This is a well-constructed layered defense for secrets. The combination of commit-time blocking, CI blocking, gitignore exclusion, and LLM read denial is appropriate defense-in-depth.

**4.2 Gaps in Secret Detection.**
- Gitleaks detection is pattern-based -- custom secret formats or internal tokens may not match known patterns
- The Claude Code deny rules use exact paths (`Read(./.env)`) which may not match nested or non-standard locations
- No data classification mechanism exists -- all data is treated identically
- Secrets that appear in log output from hook execution are not scrubbed (pre-commit hook uses `--verbose` flag for gitleaks, which may display partial secret content in terminal output)
- The framework does not provide a secrets management integration or template (e.g., vault, AWS Secrets Manager, GitHub Secrets references beyond release pipelines)

**4.3 Credentials in CI Pipeline Templates.** The release pipeline templates correctly reference `${{ secrets.* }}` for credentials (e.g., `APPLE_CERTIFICATE_BASE64`, `ANDROID_KEYSTORE_BASE64` in mobile.yml). The TODO comments guide users to store credentials as GitHub Secrets. This is correct guidance.

### Threat Model
- **Actor:** Developer accidentally committing a secret in a non-standard format; secret appearing in gitleaks verbose output
- **Attack path:** Custom API key format not in gitleaks patterns -> committed and pushed -> CI gitleaks also misses it -> secret in git history

### Severity: Low-Medium (for stated scope; multiple layers make complete bypass unlikely for standard secret formats)

### Exploitability: Low for standard formats (AWS keys, GitHub tokens, etc.). Medium for custom/internal formats.

### Remediation
1. **Medium:** Change gitleaks verbose output in pre-commit to use `--no-banner` without `--verbose` to reduce secret exposure in terminal output, or redirect verbose output to a file that is not committed.
2. **Medium:** Expand Claude Code deny rules to use glob patterns: `Read(**/.env)`, `Read(**/.env.*)`, `Read(**/*.pem)`, `Read(**/*.key)`.
3. **Low:** Add guidance for creating custom gitleaks rules for organization-specific secret patterns.
4. **Low:** Add a secrets management section to the Intake template (Section 5 or 6) that asks how secrets will be managed and stored.

---

## Category 5: Compliance Framework Compatibility

### Finding

**5.1 Exclusion Communication.** The compliance exclusion is clearly stated in multiple locations:
- README.md lines 399-404: explicitly lists SOC 2, HIPAA, PCI-DSS, FedRAMP as out of scope
- Builder's Guide lines 63-72: "not appropriate for compliance-regulated systems"
- Governance Framework lines 50-57: same exclusion with elaboration
- Executive Review (referenced): same exclusion

The communication is thorough and consistent across documents.

**5.2 No Mechanical Enforcement of Exclusion.** There is no technical control that prevents a Solo Orchestrator project from being deployed in a regulated environment. The Intake Template Section 8 includes a compliance screening matrix, but:
- It is filled out by the Orchestrator (not validated mechanically)
- No CI check validates the compliance screening answers
- No warning or block is triggered if someone selects "HIPAA" or "PCI-DSS" in the intake
- The intake wizard (`intake-wizard.sh`) does not programmatically check for regulated data types

**5.3 Compliance Gap Analysis.**

| Control | SOC 2 Type II | PCI-DSS v4 | HIPAA | SOX | FedRAMP |
|---|---|---|---|---|---|
| Change management audit trail | PARTIAL -- git history + APPROVAL_LOG.md provide audit trail, but no formal change advisory board or approval workflow enforcement | NOT PRESENT -- no cardholder data environment controls | NOT PRESENT -- no PHI handling controls, no BAA provisions | PARTIAL -- git history provides code integrity evidence | NOT PRESENT -- no FedRAMP authorization controls |
| Separation of duties | NOT PRESENT -- solo operator by design | NOT PRESENT -- single person designs, builds, tests, deploys | NOT PRESENT | NOT PRESENT | NOT PRESENT |
| Access control | PARTIAL -- private repo required (Builder's Guide line 196), branch protection not enforced by framework | NOT PRESENT -- no role-based access, no MFA enforcement | NOT PRESENT | PARTIAL -- git auth | NOT PRESENT |
| Penetration testing | PARTIAL -- Full track requires pen testing; not enforced mechanically | REQUIRED but not enforced | NOT REQUIRED by framework | NOT APPLICABLE | REQUIRED but not enforced |
| Incident response | PARTIAL -- Phase 4 generates INCIDENT_RESPONSE.md; content depends on LLM output quality | NOT PRESENT -- no PCI-specific IR procedures | NOT PRESENT -- no HIPAA breach notification | NOT APPLICABLE | NOT PRESENT |
| Data encryption at rest | NOT PRESENT -- no encryption requirements in framework | NOT PRESENT -- no encryption enforcement | NOT PRESENT | NOT APPLICABLE | NOT PRESENT |
| Data encryption in transit | NOT PRESENT -- no TLS enforcement in framework (though modern hosting platforms default to HTTPS) | NOT PRESENT | NOT PRESENT | NOT APPLICABLE | NOT PRESENT |
| Vulnerability management | PRESENT -- Semgrep SAST, dependency scanning, gitleaks (CI-enforced) | PARTIAL -- scanning present but no quarterly ASV scan, no defined remediation SLAs | PARTIAL -- scanning present but no risk analysis per 45 CFR 164.308 | PARTIAL | PARTIAL |
| Logging and monitoring | PARTIAL -- Phase 4 mentions monitoring; not enforced or validated | NOT PRESENT -- no audit log requirements met | NOT PRESENT | PARTIAL | NOT PRESENT |
| Code signing | PARTIAL -- release pipeline templates include signing TODOs; not enforced | NOT PRESENT | NOT APPLICABLE | NOT APPLICABLE | NOT PRESENT |
| SBOM generation | PRESENT -- release pipelines include CycloneDX SBOM generation | PARTIAL | NOT APPLICABLE | NOT APPLICABLE | PARTIAL |

**5.4 Partial SOC 2 Evidence.** Despite being out of scope, the framework incidentally produces evidence that partially satisfies SOC 2 CC8.1 (Change Management):
- Git history provides a complete audit trail of all code changes
- APPROVAL_LOG.md with structured phase gate approvals provides change authorization evidence
- CI pipeline provides automated testing evidence
- SAST and dependency scanning provide vulnerability management evidence

An auditor would note the absence of separation of duties, formal change advisory board review, and access control enforcement, but would acknowledge the audit trail quality.

### Threat Model
- **Actor:** Well-meaning operator deploying in regulated environment without understanding implications
- **Attack path:** Fill out intake -> skip or misunderstand compliance screening -> build and deploy app handling PII/PHI/cardholder data -> compliance violation discovered during audit or breach

### Severity: Medium (mitigated by clear documentation, but no mechanical barrier)

### Exploitability: High -- nothing prevents it

### Remediation
1. **High:** Add a mechanical check in the intake wizard: if the user indicates PII, PHI, financial data, or mentions regulated frameworks, emit a hard warning and require explicit acknowledgment that the framework is not appropriate for that use case. Optionally write a `compliance_warning` flag to `phase-state.json` that CI can check.
2. **Medium:** Add a CI check that reads the compliance screening from `PROJECT_INTAKE.md` and fails if regulated data types are indicated without an explicit waiver.
3. **Low:** Produce a "SOC 2 readiness gap" document that organizations can use to understand what additional controls would be needed if they wanted to extend a Solo Orchestrator project into a regulated environment.

---

## Category 6: Supply Chain Security

### Finding

**6.1 CI Pipeline Actions Are Pinned to Commit SHAs.** The CI templates pin third-party GitHub Actions to specific commit SHAs:
- `semgrep/semgrep-action@713efdd345f3035192eaa63f56867b88e63e4e5d` (typescript.yml line 34)
- `gitleaks/gitleaks-action@ff98106e4c7b2bc287b24eaf42907196329070c7` (typescript.yml line 41)
This is a security-positive practice that prevents tag-based supply chain attacks.

**6.2 First-Party Actions Are Not Pinned.** Standard GitHub-maintained actions use tag references:
- `actions/checkout@v4` (not SHA-pinned)
- `actions/setup-node@v4` (not SHA-pinned)
- `actions/upload-artifact@v4` (not SHA-pinned)
- `softprops/action-gh-release@v2` (not SHA-pinned)

GitHub-maintained actions have a lower risk profile than third-party actions, but tag references are still mutable. `softprops/action-gh-release` is NOT GitHub-maintained and is pinned to a tag, not a SHA.

**6.3 claude-dev-framework Clone Is Not Integrity-Verified.** As noted in Category 1, `init.sh` line 1249 clones with no verification. The `check-updates.sh` script also clones the main repo without verification (line 30). Post-init, `.claude/framework-version.txt` stores a pinned SHA, but this is recorded after the unverified clone -- it cannot detect a compromise that occurred before the SHA was recorded.

**6.4 Tool Installation from External Sources.** The tool-matrix JSON files contain install commands that fetch from external package registries:
- `npm install -g snyk` (common.json line 217)
- `pip3 install semgrep` (common.json line 168)
- Various `brew install` commands
- gitleaks binary download from GitHub releases with no checksum verification (common.json lines 192-194)

These are standard package manager commands, but the gitleaks Linux install command downloads a tarball from GitHub releases and extracts directly to `/usr/local/bin` without verifying the tarball's checksum or signature.

**6.5 No SBOM for the Framework Itself.** The framework generates SBOMs for projects it creates (via release pipeline templates), but there is no SBOM for the framework's own dependencies (the scripts, templates, and external tool requirements).

**6.6 Dependency Update Mechanism.** `check-updates.sh` compares framework documents via `diff` against a fresh clone of the upstream repo. It does NOT auto-apply changes, which is the correct security posture. However, the fresh clone (line 30) is unverified, so a compromised upstream could present malicious "updates" as legitimate changes.

### Threat Model
- **Actor:** Supply chain attacker compromising upstream repos, package registries, or GitHub Actions
- **Attack path:** Compromised `softprops/action-gh-release` tag -> malicious code in release pipeline. Or: compromised gitleaks GitHub release -> malicious binary installed via init.sh.

### Severity: Medium-High

### Exploitability
- GitHub Actions tag compromise: Demonstrated in real-world attacks (e.g., codecov/codecov-action compromise). Moderate difficulty.
- Package registry compromise: Low probability for major packages (semgrep, snyk), but supply chain attacks on npm/PyPI have precedent.

### Remediation
1. **High:** Pin `softprops/action-gh-release` to a specific commit SHA in release pipeline templates.
2. **High:** Pin `actions/checkout`, `actions/setup-node`, `actions/setup-python`, and other first-party actions to SHAs, or at minimum document why tag-based pinning is accepted for GitHub-maintained actions.
3. **High:** Add SHA256 checksum verification for the gitleaks binary download in the tool-matrix install command.
4. **Medium:** Add a verification step to `check-updates.sh` that validates the cloned repo's HEAD against a known-good commit or signed tag.
5. **Low:** Generate an SBOM for the framework itself listing all external tool dependencies and their versions.

---

## Category 7: Incident Response Implications

### Finding

**7.1 Forensic Evidence Available.** If a security incident occurs in a project built with this framework:
- **Git history** provides complete code change audit trail with timestamps and author identity
- **APPROVAL_LOG.md** provides phase gate approval records (if maintained)
- **CI pipeline logs** (GitHub Actions) provide build, test, and scan results with timestamps
- **`.claude/phase-state.json`** provides phase progression timeline
- **`.claude/build-progress.json`** provides feature completion and test session records
- **CHANGELOG.md** (if maintained) provides human-readable change history

**7.2 LLM Session History.** Claude Code session history (stored locally by the Claude Code CLI) provides context for what instructions the LLM received and what code it generated. However, this is stored on the developer's local machine and may not be available in an incident investigation if the machine is unavailable.

**7.3 Traceability to Framework Rules.** It is possible to trace a code change to:
- The git commit that introduced it
- The CI pipeline run that validated (or failed to validate) it
- The phase-state.json at the time of the commit
- The Semgrep/gitleaks scan results from that CI run

It is NOT possible to trace a code change to:
- Which specific CLAUDE.md instruction the LLM was following (or ignoring)
- Whether the Orchestrator reviewed the change at a decision gate (no attestation mechanism)
- Whether TDD ordering was followed for that specific change

**7.4 Blast Radius Analysis.** If the framework itself has a security flaw:
- **Template compromise:** Affects all projects created after the compromise. Existing projects are self-contained after init (all files are copied, not symlinked), so they are NOT retroactively affected unless `check-updates.sh` is used to apply the compromised update.
- **Hook vulnerability:** Affects all projects using the compromised hook. Hooks are copied into each project's `.git/hooks/`, so the blast radius is limited to the initial copy time.
- **CI template vulnerability:** Affects all projects using the template. CI templates are copied verbatim, so the blast radius is limited to projects created with the vulnerable template version.

The self-contained architecture (all files copied into the project, no runtime dependency on the framework repo) is a security-positive design choice that limits blast radius to creation-time contamination.

**7.5 No Incident Response Template for Framework-Level Issues.** The framework generates `docs/INCIDENT_RESPONSE.md` for application-level incidents in Phase 4, but there is no incident response procedure for framework-level security issues (e.g., "the init.sh you used to create your project was compromised").

### Threat Model
- **Actor:** Incident responder investigating a breach in a Solo Orchestrator-built application
- **Attack path:** Vulnerability in generated code -> breach -> investigation requires tracing the vulnerability's origin

### Severity: Low (forensic evidence is adequate for stated scope)

### Exploitability: N/A -- this is a capability assessment, not an attack vector

### Remediation
1. **Medium:** Add a framework-level incident response section documenting: how to determine which framework version was used to create a project, how to check if that version was compromised, and steps to remediate across the portfolio.
2. **Low:** Add a decision gate attestation mechanism (e.g., signed commit or attestation file) that records when the Orchestrator reviewed a phase gate, creating forensic evidence of review.
3. **Low:** Recommend that organizational deployments configure Claude Code session history export/backup for forensic availability.

---

## Category 8: Secure Development Lifecycle Integration

### Finding

**8.1 SAST Integration -- Strong.** Semgrep is integrated at two levels:
- Pre-commit: scans staged files with `p/owasp-top-ten` config (blocks commit)
- CI: runs `semgrep/semgrep-action` with `p/owasp-top-ten` and `p/security-audit` configs (blocks merge)
This is correct layered implementation. The pre-commit scan uses a subset of rules for speed; CI runs the full ruleset.

**8.2 SCA (Software Composition Analysis) Integration -- Strong.** Dependency scanning is language-appropriate in every CI template:
- TypeScript: `npm audit --audit-level=high` + `npm audit signatures`
- Python: `pip-audit`
- Rust: `cargo audit`
- Go: `govulncheck`
- C#: `dotnet list package --vulnerable`
- Dart: `osv-scanner`
- Swift: `osv-scanner`
- JVM: `dependencyCheckAnalyze` (plugin)

All are CI-blocking steps.

**8.3 DAST Integration -- Partial.** OWASP ZAP is included in the web release pipeline template (web.yml line 54-57) as a post-deploy scan. It is NOT included in the CI pipeline (only the release pipeline). Desktop and mobile release templates include ZAP as a commented-out optional step. DAST during development (Phase 2) is not mechanically enforced -- it relies on the LLM following instructions to use ZAP.

**8.4 License Compliance -- Strong.** Every CI template includes a license check that fails on copyleft licenses:
- TypeScript: `license-checker --failOn "GPL-2.0;GPL-3.0;AGPL-3.0;LGPL-*;SSPL-1.0;EUPL-*"`
- Python: `pip-licenses --fail-on="GPLv2;GPLv3;AGPLv3;LGPLv*;SSPL;EUPL"`
- Other languages: equivalent tools

This is a genuine enforcement control that many professional CI setups lack.

**8.5 OWASP Top 10 Coverage.**

| OWASP Top 10 (2021) | Framework Coverage | Enforcement Level |
|---|---|---|
| A01: Broken Access Control | Semgrep patterns; LLM security audit persona; threat model in Phase 1 | Partial (SAST catches patterns, not logic) |
| A02: Cryptographic Failures | Semgrep detects insecure hash algorithms | Partial |
| A03: Injection | Semgrep p/owasp-top-ten covers SQL injection, XSS, command injection | Strong (pattern-based) |
| A04: Insecure Design | Phase 1 threat model; security scan guide | Advisory only |
| A05: Security Misconfiguration | Semgrep security-audit config; .gitignore template | Partial |
| A06: Vulnerable Components | npm audit / pip-audit / cargo audit / etc. in CI | Strong |
| A07: Authentication Failures | Semgrep patterns; LLM security audit | Partial |
| A08: Software and Data Integrity | CI action SHA pinning (partial); lockfile integrity (npm only); SBOM in release | Partial |
| A09: Security Logging Failures | CLAUDE.md instructs structured logging; no enforcement | Advisory only |
| A10: SSRF | Semgrep patterns | Partial |

**8.6 Security-Focused Code Review.** The framework does not integrate with a code review tool (no PR review requirements, no CODEOWNERS file generated, no branch protection rules configured). The CLAUDE.md template instructs the LLM to perform security audits per feature, and the evaluation prompts provide adversarial review perspectives, but these are LLM-executed reviews, not human peer reviews. For the solo operator model, this is inherent -- there is no peer to review. The governance framework's "Senior Technical Authority" review at Phase 1->2 and IT Security review at Phase 3->4 are the designated human review points.

### Threat Model
- **Actor:** LLM generating code with vulnerability patterns not covered by SAST rules
- **Attack path:** Novel injection pattern or logic flaw -> not detected by Semgrep -> passes CI -> deployed

### Severity: Low-Medium (SAST coverage is strong for known patterns; logic flaw coverage is inherently limited)

### Exploitability: Medium for logic flaws; Low for known patterns (Semgrep catches them)

### Remediation
1. **Medium:** Add DAST (ZAP baseline scan) as a CI step for web projects, not just the release pipeline. This catches runtime vulnerabilities that SAST misses.
2. **Medium:** Generate a `.github/CODEOWNERS` file and configure branch protection rules requiring PR review before merge to main (at least for organizational deployments).
3. **Low:** Add Semgrep custom rules for the specific language/framework combination selected (e.g., Next.js-specific rules, Django-specific rules) in addition to the generic p/owasp-top-ten and p/security-audit configs.

---

## Security Controls Matrix

| Security Feature | Status | Enforcement Level | File Reference |
|---|---|---|---|
| SAST scanning (Semgrep) | PRESENT | **Enforced** (CI blocks merge + pre-commit blocks commit) | `templates/pipelines/ci/*.yml`, `init.sh` lines 1554-1569 |
| Secret detection (gitleaks) | PRESENT | **Enforced** (CI blocks merge + pre-commit blocks commit) | `templates/pipelines/ci/*.yml`, `init.sh` lines 1540-1551 |
| Dependency vulnerability scan | PRESENT | **Enforced** (CI blocks merge) | `templates/pipelines/ci/*.yml` |
| License compliance check | PRESENT | **Enforced** (CI blocks merge) | `templates/pipelines/ci/*.yml` |
| Test execution gate | PRESENT | **Enforced** (CI blocks merge) | `templates/pipelines/ci/*.yml` |
| Build gate | PRESENT | **Enforced** (CI blocks merge) | `templates/pipelines/ci/*.yml` |
| Phase gate consistency | PRESENT | **Partially Enforced** (CI blocks, but bypassable via SOIF_PHASE_GATES=warn) | `scripts/check-phase-gate.sh`, `templates/pipelines/ci/*.yml` |
| POC production block | PRESENT | **Partially Enforced** (check-phase-gate.sh blocks Phase 4, but only if script is invoked) | `scripts/check-phase-gate.sh` lines 101-109 |
| Lockfile integrity | PRESENT | **Partially Enforced** (npm only: npm audit signatures) | `templates/pipelines/ci/typescript.yml` line 54 |
| Secrets in .env files | PRESENT | **Partially Enforced** (gitignore + Claude deny rules + gitleaks) | `templates/generated/gitignore-base.tmpl`, `init.sh` lines 1220-1221 |
| TDD ordering | PRESENT | **Advisory** (pre-commit warns, does not block) | `init.sh` lines 1575-1604 |
| Schema migration discipline | PRESENT | **Advisory** (pre-commit warns, does not block) | `init.sh` lines 1608-1638 |
| Changelog maintenance | PRESENT | **Advisory** (CI warns; optional strict mode) | `scripts/check-changelog.sh` |
| CLAUDE.md session freshness | PRESENT | **Advisory** (CI warns; optional strict mode) | `scripts/check-session-state.sh` |
| Test-fix-verify loop | PRESENT | **Advisory** (test-gate.sh is a checkpoint, not CI-integrated) | `scripts/test-gate.sh` |
| Phase gate approval identity | PRESENT | **Not Enforced** (policy says approver must commit; no mechanical check) | `docs/governance-framework.md` lines 176-183 |
| No regulated environment deployment | DOCUMENTED | **Not Enforced** (documentation only, no mechanical barrier) | `README.md`, `docs/governance-framework.md`, `docs/builders-guide.md` |
| Branch protection | NOT PRESENT | **Not Present** (not configured by framework) | N/A |
| Code review requirement | NOT PRESENT | **Not Present** (no PR review enforcement) | N/A |
| DAST during development | NOT PRESENT | **Not Present** (only in release pipeline) | N/A |
| Data classification | NOT PRESENT | **Not Present** | N/A |
| Encryption at rest/in transit | NOT PRESENT | **Not Present** | N/A |
| Framework integrity verification | NOT PRESENT | **Not Present** (no checksums or signatures) | N/A |
| SBOM for framework itself | NOT PRESENT | **Not Present** | N/A |

---

## Compliance Gap Analysis

| Compliance Framework | Framework Readiness | Key Gaps |
|---|---|---|
| **SOC 2 Type II** | ~25% -- change management audit trail present; access control, separation of duties, monitoring absent | No separation of duties (inherent to solo model); no access control enforcement; no monitoring/alerting validation; no formal change advisory board |
| **PCI-DSS v4** | ~10% -- dependency scanning and SAST present; everything else absent | No cardholder data environment controls; no network segmentation; no encryption enforcement; no access control; no quarterly ASV scans; no penetration testing enforcement |
| **HIPAA** | ~5% -- no PHI-specific controls whatsoever | No BAA provisions; no PHI handling controls; no access logging; no encryption; no minimum necessary standard implementation; no breach notification procedures |
| **SOX** | ~20% -- git audit trail and CI provide code integrity evidence | No separation of duties; no formal approval workflow enforcement; no financial reporting controls |
| **FedRAMP** | ~5% -- virtually nothing applicable | No authorization controls; no continuous monitoring; no FIPS compliance; no personnel security; no physical security considerations |
| **GDPR/CCPA** | ~15% -- intake asks about data handling; no mechanical enforcement | No data subject rights implementation; no consent management; no data retention controls; no DPO designation; no DPIA template |

---

## Hard Stops

The Solo Orchestrator Framework **MUST NOT** be used for:

1. **Any system processing, storing, or transmitting PII/PHI/PCI data** without substantial additional controls (encryption, access control, audit logging, data classification, retention policies, breach notification procedures) that are outside the framework's scope.

2. **Any system subject to SOC 2, HIPAA, PCI-DSS, FedRAMP, or SOX compliance requirements.** The framework lacks separation of duties, formal change management workflows, access control enforcement, encryption requirements, and continuous monitoring -- all of which are non-negotiable for these frameworks.

3. **Any system with uptime SLAs above 99.9%.** The solo operator model is a single point of failure for incident response.

4. **Any system where a security breach would result in regulatory notification requirements** (state breach notification laws, GDPR Article 33, HIPAA breach notification rule).

5. **Any environment where the framework's upstream repositories cannot be verified** (air-gapped networks without pre-validated copies, environments requiring FIPS-validated cryptographic modules).

---

## Minimum Viable Security Additions

Before the framework can be used in any environment handling even mildly sensitive internal data (employee directories, internal financial dashboards, internal workflow tools):

1. **Framework integrity verification.** Add SHA256 checksums for all template files in a signed manifest. Verify on clone and update.

2. **Eliminate eval-based command execution.** Replace all `eval "$cmd"` patterns with a restricted command dispatcher that validates commands against a whitelist.

3. **Branch protection enforcement.** Generate a GitHub branch protection configuration (or equivalent) that requires: CI passing, at least one review approval (even if self-review for personal projects), and no force pushes to main.

4. **Expanded secret deny patterns for LLM.** Broaden Claude Code deny rules to cover nested paths and additional sensitive file types.

5. **Regulated environment gate.** Add a mechanical check in the intake wizard and CI pipeline that flags or blocks if compliance-regulated data types are indicated.

6. **Pin all CI action references to SHAs.** Especially `softprops/action-gh-release` and `actions/checkout`.

7. **Add DAST to CI for web projects.** Move ZAP baseline scan from release-only to CI pipeline.

---

## Overall Security Rating

### **CONDITIONALLY APPROVED**

**Justification:**

The Solo Orchestrator Framework demonstrates a security posture that is:

1. **Honest.** The framework is transparent about what is enforced and what is advisory. The three-tier enforcement model is clearly documented with specific categorization of every control. This level of security honesty is rare and valuable -- it prevents the false confidence that is more dangerous than acknowledged gaps.

2. **Mechanically sound at the CI layer.** The Tier 1 controls (SAST, secret detection, dependency scanning, license compliance, build/test gates) are real enforcement mechanisms that block merges. The SHA-pinned third-party CI actions demonstrate awareness of supply chain risks.

3. **Appropriately scoped.** The framework explicitly and repeatedly excludes regulated environments and high-availability systems. The target scope (internal tools, MVPs, departmental applications) is one where the framework's security posture provides genuine improvement over the realistic alternative (unstructured development with no security tooling).

4. **Better than the alternative.** Compared to the three realistic alternatives (project stays in backlog, unstructured "vibe coding" with AI, shadow IT spreadsheet workarounds), the framework provides dramatically better security controls. This is the correct comparison baseline.

**Conditions for approval:**

- **P0 (before any organizational deployment):** Eliminate eval-based command execution from JSON sources; pin all CI action references to SHAs; add framework integrity verification (checksums at minimum).
- **P1 (before handling any internal sensitive data):** Add branch protection rules; expand LLM secret deny patterns; add regulated environment gate in intake wizard.
- **P2 (before production use by multiple orchestrators):** Add framework-level incident response procedures; add DAST to CI for web projects; add commit-author verification for approval log entries.

The framework should not be blocked from personal and internal tool use in its current state. The identified vulnerabilities (eval injection, supply chain integrity, scope creep) are real but require either local file access or upstream repository compromise to exploit -- neither of which is elevated risk for the solo operator model on personal projects. For organizational deployment, the P0 remediations must be completed first.

---

*This review was conducted as a read-only security assessment. No framework files were modified. No vulnerabilities were exploited. All findings are based on source code review and documented behavior analysis.*
