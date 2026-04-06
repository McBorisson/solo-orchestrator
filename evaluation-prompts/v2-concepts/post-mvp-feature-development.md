# Post-MVP Feature Development Cycle — v2 Concept

## Problem Statement

The Solo Orchestrator framework takes a project from idea to production (Phases 0-4). Once Phase 4 is complete, the Orchestrator needs to continue adding features, fixing bugs, and evolving the product. The framework currently has no documented workflow for this ongoing development cycle.

The Build Loop (Phase 2's TDD cycle) is reusable, but the phase gate structure is designed as a one-time linear progression. Post-MVP development is iterative, not linear.

## Key Design Questions

1. **Scope classification**: How does the Orchestrator decide whether a change is:
   - A bug fix (straight to Build Loop, no architecture review)
   - A small feature (lightweight design review, then Build Loop)
   - A significant feature (mini Phase 1 architecture review, then Phase 2-3 cycle)
   - A major evolution (full Phase 1 re-engagement, new threat model, potential re-architecture)

2. **Phase re-entry**: Does the Orchestrator re-enter Phase 2 for each feature? Or is there a distinct "Phase 5: Ongoing Development" that has its own lighter-weight process?

3. **Validation scaling**: Phase 3 is a full hardening pass (security audit, performance, UAT, accessibility). For a single feature addition, the full Phase 3 is overkill. What's the right validation scope for:
   - A 1-day bug fix
   - A 1-week feature
   - A multi-week feature that touches auth or data model

4. **Release cadence**: Phase 4 assumes a single launch event. Post-MVP, releases are continuous. How does the framework handle:
   - Feature branches vs. trunk-based development
   - Release tagging and changelog maintenance
   - Rollback procedures for individual features
   - Feature flags for gradual rollout

5. **Project Bible maintenance**: The Project Bible is created in Phase 1 as a snapshot. As features are added, the architecture evolves. How does the Bible stay current without becoming a maintenance burden?

6. **Regression prevention**: With ongoing changes, the risk of regression grows. What additional controls are needed:
   - Test coverage thresholds (don't merge if coverage drops)
   - Performance benchmarks (don't merge if p95 latency increases)
   - Dependency drift monitoring between features

7. **Context management**: The Orchestrator's context with the AI resets between sessions. For ongoing development, the AI needs to re-learn the codebase each session. How does the framework help with:
   - Session resume (the resume.sh script exists but may need enhancement)
   - Feature context handoff between sessions
   - Avoiding the AI re-suggesting already-rejected approaches

## Decision: Extend or Separate?

This concept should be evaluated as either:

**Option A: Extend the existing framework** — Add a "Phase 5: Ongoing Development" section to the Builder's Guide with a lighter-weight loop that references existing Phase 2-3 mechanisms. Add a feature classification decision tree. Add release management guidance.

**Option B: Create a separate "Feature Development Kit"** — A standalone, lighter-weight tool specifically for adding features to existing projects. It would:
- Assume the project already has CI, tests, security scanning in place
- Provide a feature intake template (scope, acceptance criteria, affected components)
- Run a mini Build Loop with appropriate validation
- Handle branching, PR creation, changelog updates
- Skip all the governance, intake, and Phase 0-1 infrastructure

**Option C: Hybrid** — Extend the framework with Phase 5 guidance (documentation only), but also offer a standalone CLI tool or script for the tactical feature loop (the operational tooling).

## Evaluation Criteria

When deciding between options, consider:
- Does the Orchestrator who built the MVP need the same level of scaffolding for feature work?
- Would a new Orchestrator inheriting a Phase 4 project need the full framework or just the feature kit?
- Does combining greenfield and brownfield workflows in one tool create confusion?
- Is the maintenance burden of two tools worse than the complexity of one tool doing both?
