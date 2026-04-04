# Upgrade Path Test Suite Report
**Date:** 2026-04-03
**Runner:** tests/upgrade-path-tests.sh
**Result:** ALL 56 TESTS PASSED (0 failures, 0 warnings)

---

## TEST 1: Resolver Tool Changes Across Track Upgrades

For each platform (web, mobile, desktop), resolved at light -> standard -> full and verified each higher track has more (or equal) tools and no tools are lost.

| Platform | Light | Standard | Full | Result |
|----------|-------|----------|------|--------|
| web      | 12    | 16       | 17   | PASS   |
| mobile   | 16    | 19       | 19   | PASS   |
| desktop  | 13    | 16       | 16   | PASS   |

- No tools lost from light -> standard on any platform
- No tools lost from standard -> full on any platform

## TEST 2: Tool Preferences Context Update on Upgrade

- Standard track correctly includes Lighthouse (standard/full-only tool)
- Light track correctly excludes Lighthouse
- Deferred at phase 2: light=0, standard=3
- Standard at phase 2 has more deferred tools than light
- Upgraded preferences (light -> standard) resolves correctly

## TEST 3: Phase-Gate Tool Surfacing on Upgrade

| State             | Deferred | Details |
|-------------------|----------|---------|
| light/phase 2     | 0        | No phase 3+ tools in light track |
| standard/phase 2  | 3        | OWASP ZAP, license-checker, Playwright |
| standard/phase 3  | 0        | All 3 surfaced as active |

- OWASP ZAP, license-checker, and Playwright all correctly surfaced at phase 3
- Phase-gate filtering correctly separates active from deferred

## TEST 4: Deployment Type Validation

- init.sh distinguishes organizational vs personal deployment
- Organizational approval log includes 5/5 governance role markers (IT Security, Legal, Executive Sponsor, ITSM, Backup maintainer)
- Personal approval log marks pre-conditions as N/A
- Intake template includes deployment type selection
- Governance framework references organizational deployments and exempts personal projects

## TEST 5: Upgrade Path Validation

### Track Transitions

| From     | To       | Status  | Evidence |
|----------|----------|---------|----------|
| light    | standard | ALLOWED | tools: 12 -> 16 |
| light    | full     | ALLOWED | tools: 12 -> 17 |
| standard | full     | ALLOWED | tools: 16 -> 17 |
| full     | standard | BLOCKED | would lose: k6 |
| standard | light    | BLOCKED | would lose: Lighthouse, OWASP ZAP, Playwright, license-checker |
| full     | light    | BLOCKED | would lose: Lighthouse, OWASP ZAP, Playwright, k6, license-checker |

### Deployment Transitions

| From           | To             | Status  |
|----------------|----------------|---------|
| personal       | organizational | ALLOWED |
| organizational | personal       | BLOCKED |

## TEST 6: No Tool Regression on Upgrade (Strict Superset)

### web/typescript Reference

- Light (12 tools): Claude Code, Context7 MCP, Docker, GPG, Git, Node.js, Qdrant MCP, Semgrep, Snyk CLI, Superpowers, gitleaks, jq
- Standard adds (+4): Lighthouse, OWASP ZAP, Playwright, license-checker
- Full adds (+1): k6

Verification: light tools are a SUBSET of standard, standard tools are a SUBSET of full (strict supersets confirmed).

### Cross-Platform Regression Check

All 6 platform/language combinations verified (mobile/typescript, mobile/dart, mobile/rust, desktop/typescript, desktop/dart, desktop/rust) -- all light subsets of standard, all standard subsets of full.
