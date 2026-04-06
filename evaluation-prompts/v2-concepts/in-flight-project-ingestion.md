# In-Flight Project Ingestion — v2 Concept

## Problem Statement

The Solo Orchestrator framework assumes a greenfield project — fresh directory, no existing code, linear Phase 0-4 progression. Many real-world scenarios involve existing projects:

- A prototype that was "vibe coded" and now needs structure
- An internal tool built by someone who left the organization
- A side project that grew beyond its original scope
- A codebase inherited from a contractor or acquired company
- An existing project the Orchestrator wants to bring under framework governance

The framework currently cannot adopt these projects without starting over.

## Key Design Questions

### 1. Codebase Assessment

Before ingesting a project, the framework needs to understand what exists:

- **Language and stack detection**: What languages, frameworks, build tools are present?
- **Test coverage**: Does the project have tests? What kind (unit, integration, e2e)? What's the coverage?
- **Security posture**: Is there CI? SAST? Dependency scanning? Secret detection?
- **Documentation**: Is there a README? API docs? Architecture docs? Inline comments?
- **Dependency health**: Are dependencies pinned? Are there known vulnerabilities? License issues?
- **Code quality**: Linting configured? Consistent style? Dead code?
- **Infrastructure**: Where is it deployed? What hosting? What monitoring?

This assessment determines which phase the project is effectively at and what gaps exist.

### 2. Phase Mapping

An existing project doesn't fit neatly into Phase 0-4. It might have:
- Production deployment (Phase 4) but no tests (Phase 2 gap)
- Good architecture docs (Phase 1) but no security scanning (Phase 2 gap)
- Tests and CI (Phase 2-3) but no intake or product definition (Phase 0 gap)

The ingestion process needs to:
- Map existing artifacts to framework phases
- Identify gaps per phase
- Create a remediation plan that addresses gaps without disrupting what works
- Assign a "current effective phase" that reflects reality

### 3. Non-Destructive Integration

The framework must wrap around the existing project, not replace it:

- **Existing CI**: Merge framework CI steps into existing pipelines, don't overwrite
- **Existing tests**: Adopt existing test structure, don't impose a new one
- **Existing git history**: Preserve all history, don't require a fresh repo
- **Existing deployment**: Document current deployment, don't change it during ingestion
- **Existing dependencies**: Audit but don't force updates during ingestion (catalog first, remediate later)

### 4. Retroactive Documentation

The framework's value partly comes from documentation artifacts (Intake, Project Bible, ADRs, threat model). For an existing project, these need to be generated retroactively:

- **Project Intake**: Can be partially auto-filled from package.json, README, existing docs
- **Project Bible**: Architecture section can be generated from codebase analysis (directory structure, dependency graph, API routes)
- **Threat Model**: Can be generated from the existing architecture, but needs human validation
- **ADRs**: Past decisions are lost unless documented in commit messages or issues — framework should acknowledge this gap

### 5. Technical Debt Acknowledgment

Ingested projects likely have technical debt that a greenfield project wouldn't. The framework needs to:

- Catalog known debt without requiring immediate remediation
- Distinguish between "debt we accept for now" and "debt that blocks framework compliance"
- Create a debt remediation roadmap that aligns with the phase gate model
- Not block the Orchestrator from making progress while debt exists

### 6. Handoff Scenario

A common ingestion case: someone else built it, the Orchestrator is taking over. This adds:

- **Knowledge transfer**: What does the Orchestrator need to learn about the codebase?
- **Access transfer**: Hosting credentials, API keys, deployment pipelines, monitoring
- **Risk assessment**: What landmines exist? What's fragile? What's undocumented?
- **HANDOFF.md generation**: The framework already has a handoff template — can it be generated for the incoming direction (receiving a project, not handing one off)?

## Decision: Extend or Separate?

**Option A: Add an `--ingest` flag to init.sh** — Runs in a different mode that scans the existing project, generates a gap analysis, creates framework files non-destructively, and produces a remediation plan. Same tool, different entry point.

**Option B: Create a separate "Project Adoption Kit"** — A standalone tool specifically for bringing existing projects under framework governance. It would:
- Run a comprehensive codebase assessment (automated scanning + guided questionnaire)
- Generate a gap analysis report comparing current state to framework requirements
- Produce a phased remediation plan
- Create framework artifacts (Intake, Bible, phase-state) pre-populated from scan results
- Install framework tooling (CI, hooks, security scanning) non-destructively
- Support incremental adoption (start with CI + security, add governance later)

**Option C: Hybrid** — The assessment and gap analysis are a separate tool (useful even without full framework adoption). The remediation and framework file generation are an init.sh mode.

## Evaluation Criteria

- How different is the ingestion workflow from greenfield? If >60% different, separate tools.
- Does the Orchestrator ingesting a project need the full Phase 0-4 documentation, or a subset?
- Can the assessment tool be useful standalone (e.g., "audit this codebase" without adopting the framework)?
- Would organizations want to run the assessment on multiple projects before deciding which ones to adopt into the framework?
- Is the maintenance burden of a separate tool justified by the clarity of having distinct entry points for distinct workflows?

## Relationship to Post-MVP Feature Development

If the framework has three modes:
1. **Greenfield** (current): Phase 0-4, idea to production
2. **Ingestion** (this concept): Adopt existing project, remediate gaps
3. **Feature Development** (other concept): Ongoing work on a production project

Then ingestion is the bridge — it brings a project to a state where either the greenfield phases (if significant gaps) or the feature development cycle (if mostly complete) can take over. The ingestion tool's output should clearly indicate which path to follow next.
