# Solo Orchestrator Framework

A structured software development methodology where a single experienced technologist builds production-grade applications using AI as the execution layer. The human defines intent, constraints, and validation. The AI generates architecture, code, tests, and documentation within those constraints.

This is not vibe coding. It's a phase-gated, test-driven, documentation-mandatory process with security scanning, threat modeling, and incident response built in.

### AI Agent: Claude Code

**This framework is built on and tested with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (Anthropic).** The init script, CLAUDE.md configuration, Superpowers plugin, MCP server integrations, and CLI Setup Addendum are all Claude Code-specific.

The methodology itself — the phases, TDD discipline, threat modeling, documentation mandates, and security scanning — is agent-agnostic and works with any sufficiently capable AI coding agent. The operational automation layer that makes the autonomous workflow practical is Claude Code. See [Vendor Dependency & Exit Path](#vendor-dependency--exit-path) for migration details.

---

## Quick Start

```bash
git clone https://github.com/kraulerson/solo-orchestrator.git
cd solo-orchestrator
chmod +x init.sh
./init.sh
```

The init script will:
1. Check prerequisites (Node.js 18+, Git)
2. Collect your project information (name, platform, track)
3. Install security tooling (Semgrep, gitleaks, Snyk, Claude Code)
4. Create your project directory with all framework documents copied in
5. Generate `CLAUDE.md`, `.gitignore`, and CI/CD template
6. Initialize Git and run a health check
7. Print your next steps

**After init completes:**
1. Authenticate: `claude` (OAuth) and `snyk auth`
2. Fill out `PROJECT_INTAKE.md` — this is your product definition
3. Start Claude Code and tell it to begin

---

## Prerequisites

| Tool | Required | Install |
|---|---|---|
| **Node.js 18+** | Yes | [nodejs.org](https://nodejs.org/) (LTS) |
| **Git** | Yes | [git-scm.com](https://git-scm.com/downloads) |
| **Docker** | Recommended | [docker.com](https://www.docker.com/) — needed for OWASP ZAP DAST scanning |
| **Claude Code** | Recommended (framework is optimized for Claude Code; other AI coding agents can be used but the CLI Setup Addendum and Phase 2 workflow accelerators are Claude Code-specific) | Installed by init script, or manually: `brew install claude-code` (macOS), `winget install Anthropic.ClaudeCode` (Windows) |

### Windows Users

**Windows Subsystem for Linux (WSL) is required.** The init script, Claude Code, and the development toolchain (Git hooks, bash scripts, Unix CLI tools) require a Linux environment. Native Windows CMD/PowerShell will not work.

```bash
# Install WSL (PowerShell as Administrator)
wsl --install

# After restart, open Ubuntu from the Start menu
# Then install Node.js inside WSL:
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs git

# Clone and run from within WSL, not from Windows
```

All subsequent commands in this README and the Builder's Guide assume a Unix-like terminal (macOS Terminal, Linux shell, or WSL on Windows).

The init script handles installation of Semgrep, gitleaks, Snyk CLI, Lighthouse, and OWASP ZAP.

---

## What Gets Created

When you run `init.sh`, it creates a project directory with this structure:

```
your-project/
├── CLAUDE.md                           # Agent instructions (auto-generated)
├── PROJECT_INTAKE.md                   # Your product definition (fill this out)
├── .github/workflows/ci.yml           # CI/CD template
├── .gitignore                          # Platform-appropriate ignores
├── docs/
│   ├── framework/
│   │   ├── builders-guide.md           # The complete methodology
│   │   ├── governance-framework.md     # Enterprise governance (if organizational)
│   │   ├── executive-review.md         # CIO business case
│   │   └── cli-setup-addendum.md       # Claude Code configuration
│   ├── platform-modules/
│   │   └── [your-platform].md          # Platform-specific guidance
│   └── test-results/                   # Phase 3 test evidence (populated during build)
```

All framework documents are copied into the project. Each project is self-contained — no external dependencies on this repo after init.

---

## How It Works

### The Documents

| Document | Purpose | Audience |
|---|---|---|
| **Builder's Guide** | Platform-agnostic methodology. Phases 0-4, prompts, remediation tables, glossary. | Solo Orchestrator |
| **Project Intake Template** | Structured input. Every decision the AI needs to work autonomously. | Solo Orchestrator |
| **Enterprise Governance Framework** | Approval authorities, compliance, risk, portfolio governance. | CIO, IT Security, Legal |
| **Executive Review** | Business case for CIO evaluation. | CIO, VP Engineering |
| **CLI Setup Addendum** | Claude Code configuration: Superpowers, Claude Dev Framework (Git hook guardrails), MCP servers (Context7, Qdrant), CLAUDE.md. | Solo Orchestrator |
| **Platform Modules** | Platform-specific architecture, tooling, testing, distribution. | Solo Orchestrator |

### The Process

```
Phase 0: Product Discovery        → Product Manifesto
Phase 1: Architecture & Planning   → Project Bible (+ Threat Model)
Phase 2: Construction (Loom)       → Working codebase + tests + docs
Phase 3: Validation & Security     → Scan results + test evidence
Phase 4: Release & Maintenance     → Production deployment + monitoring
```

Each phase produces artifacts that gate entry into the next phase. The AI executes within constraints. The human validates at decision gates.

### The Workflow

1. **Fill out the Intake** — product decisions, constraints, technical preferences
2. **Start Claude Code** — point it at the Intake and Builder's Guide
3. **The agent executes Phases 0-4** — asking you only for clarifying questions
4. **You review at decision gates** — architecture selection, test assertions, go-live
5. **You test the MVP** — pass/fail

---

## Platform Support

### Production-Ready

| Platform | Module | Status |
|---|---|---|
| **Web** (SPA, full-stack, API) | `web.md` | v1.0 — Complete |
| **Desktop** (Windows, macOS, Linux) | `desktop.md` | v1.0 — Complete |
| **Mobile** (iOS, Android) | `mobile.md` | v1.0-stub — Preliminary |

### Roadmap

| Platform | Module | Status |
|---|---|---|
| **CLI** | — | No dedicated module. Core guide works standalone for simple CLI tools. |

New platform modules can be added without modifying the core framework. A module is production-ready when it covers: Architecture → Tooling → Build & Packaging → Testing → Distribution → Maintenance.

---

## Project Tracks

| Track | When | What Changes |
|---|---|---|
| **Light** | Internal tools, personal utilities, <10 users | Skip market audit. Abbreviated Phase 3. Basic Phase 4. |
| **Standard** | External users, moderate complexity, <$10K/month | All phases. Lightweight market validation. |
| **Full** | Enterprise buyers, sensitive data, >$10K/month | All phases at max depth. Customer interviews. Pen testing mandatory. |

---

## Optional Enhancements

These are configured per the [CLI Setup Addendum](docs/cli-setup-addendum.md):

| Tool | What It Does |
|---|---|
| **Superpowers** | Agentic skills plugin for Claude Code. Subagent-driven development, strict TDD, systematic debugging, git worktrees. Phase 2 workflow accelerator. |
| **Claude Dev Framework** | Git hook-based guardrails for coding standards, security scanning, and documentation. Swiss cheese defense model. **Auto-installed by init.sh** into `.claude/framework/` with the appropriate profile for your platform. This is a separate project (github.com/kraulerson/claude-dev-framework) that can be used independently. The Solo Orchestrator init script installs it automatically, but it is not required. |
| **Context7 MCP** | Provides Claude with up-to-date library documentation during architecture selection and construction. |
| **Qdrant MCP** | Persistent semantic memory across Claude Code sessions. Stores project decisions and patterns. |

---

## For CIOs and Enterprise Evaluation

The [Executive Review](docs/executive-review.md) is designed to be evaluated independently — including by AI models. The [Enterprise Governance Framework](docs/governance-framework.md) provides the approval authorities, compliance screening, risk management, and portfolio governance required for organizational adoption.

Evaluation prompts for stress-testing the framework are in `evaluation-prompts/`:
- **CIO Evaluation** — 10 business dimensions, 6 technical dimensions
- **Red Team Evaluation** — 15 security attack surface areas
- **Legal Analysis** — 15 legal risk domains

---

## Vendor Dependency & Exit Path

The framework is optimized for Claude Code. Here's what's portable and what requires retooling:

**Portable (works with any AI agent):**
- The methodology: phases, decision gates, quality controls
- All document artifacts: Product Manifesto, Project Bible, ADRs, test results, HANDOFF.md
- Security tooling: Semgrep, gitleaks, Snyk, OWASP ZAP, SBOM generation
- CI/CD pipeline, Git hooks, testing frameworks
- The Intake Template and Governance Framework

**Claude Code-specific (requires retooling to switch):**
- CLAUDE.md → equivalent agent configuration file for the new agent
- Superpowers plugin → equivalent agentic skills (subagent dispatch, TDD enforcement, worktrees)
- Context7 / Qdrant MCP servers → equivalent context and memory tools (or manual context management)
- CLI Setup Addendum → rewrite for new agent's configuration model
- Init script CLAUDE.md generation → rewrite template for new agent

**Estimated retooling per active project:** 2-4 weeks, primarily spent on: rewriting the agent configuration, validating the new agent produces comparable output quality on the existing codebase, and adjusting prompts. The codebase, tests, documentation, and security tooling transfer without modification.

**Risk mitigation:** Periodically verify that the Project Bible produces coherent output when provided to a different AI agent. If the Bible is well-written, the project is recoverable regardless of which agent built it.

---

## What This Is Not

- Not for compliance-regulated systems (SOC 2, HIPAA, PCI-DSS, FedRAMP)
- Not for high-availability systems (99.99%+ SLA)
- Not for large-scale distributed systems (microservices, multi-region)
- Not for enterprise integration projects (SAP, Salesforce, ERP)

It's for the projects that sit in the backlog because they don't justify a team: internal tools, departmental applications, prototypes, MVPs, and utilities.

## Current Status

This is the initial release of the Solo Orchestrator Framework. It has been used by the author to build personal projects but has not yet been validated through a formal organizational pilot. The framework's own pilot evaluation process (see Executive Review, Section X) defines how to test it. Treat this as a well-structured hypothesis, not a proven methodology. Feedback from real-world usage will drive future iterations.

---

## Document Versions

| Document | Version | Date |
|---|---|---|
| Builder's Guide | v1.0 | 2026-04-02 |
| Enterprise Governance Framework | v1.0 | 2026-04-02 |
| Executive Review | v1.0 | 2026-04-02 |
| Project Intake Template | v1.0 | 2026-04-02 |
| CLI Setup Addendum | v1.0 | 2026-04-02 |
| Platform Module: Web | v1.0 | 2026-04-02 |
| Platform Module: Desktop | v1.0 | 2026-04-02 |
| Platform Module: Mobile | v1.0-stub | 2026-04-02 |

---

## License

MIT — see [LICENSE](LICENSE).
