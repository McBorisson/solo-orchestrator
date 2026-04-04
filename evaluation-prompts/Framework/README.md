# Solo Orchestrator Framework — Review Suite

Six independent review prompts designed to critically evaluate the Solo Orchestrator Framework from distinct professional perspectives. Each runs in its own Claude Code CLI instance with full project access.

## Reviews

| # | Reviewer | Output File | Focus |
|---|----------|-------------|-------|
| 1 | Senior Software Engineer (20+ yr) | `senior-engineer-review-v1.md` | Architecture, enforcement integrity, cross-platform credibility, real-world viability |
| 2 | CIO (startup to Fortune 500) | `cio-review-v1.md` | TCO, vendor risk, governance, scalability, strategic positioning |
| 3 | SVP IT Security | `security-review-v1.md` | Attack surfaces, LLM security boundaries, compliance gaps, enforcement vs. theater |
| 4 | Corporate Legal / General Counsel | `legal-review-v1.md` | Licensing, AI-generated code IP, regulatory compliance, liability exposure |
| 5 | Technical User (non-coder) | `technical-user-review-v1.md` | Onboarding, usability, documentation quality, personal/enterprise viability |
| 6 | Red Team Engineer / AppSec Architect | Inline deliverable (two-part assessment) | Methodology attack surface, exploitable weaknesses, bypass paths, false sense of security |

## Directory Structure

```
Framework/
├── README.md                          # This file
├── run-reviews.sh                     # Orchestrates review execution
├── 01-senior-engineer-review.md       # Senior Engineer prompt
├── 02-cio-review.md                   # CIO prompt
├── 03-security-review.md              # SVP IT Security prompt
├── 04-legal-review.md                 # Corporate Legal prompt
├── 05-technical-user-review.md        # Technical User prompt
└── 06-red-team-evaluation.md          # Red Team prompt
```

## Usage

### Run all reviews from the solo-orchestrator repo root

```bash
cd /path/to/solo-orchestrator
chmod +x evaluation-prompts/Framework/run-reviews.sh
./evaluation-prompts/Framework/run-reviews.sh
```

### Run individual reviews

```bash
cd /path/to/solo-orchestrator

# Run a single review
./evaluation-prompts/Framework/run-reviews.sh 1      # Engineer only
./evaluation-prompts/Framework/run-reviews.sh 3 4    # Security + Legal

# Or run directly with claude -p
claude -p "$(cat evaluation-prompts/Framework/01-senior-engineer-review.md)"
```

### Set framework path externally

```bash
FRAMEWORK_DIR=/path/to/solo-orchestrator \
./evaluation-prompts/Framework/run-reviews.sh
```

### Use with a different LLM

Paste the prompt file contents into any capable LLM alongside the framework documentation. The prompts are not Claude-specific — they work with any model that can read files and produce structured analysis.

## What to Expect

- Each review reads **every file** in the project before writing its assessment
- Reviews take 5-15 minutes each depending on project size and model throughput
- Output files land in the project root directory (except review 6, which outputs inline)
- Reviews are intentionally critical — they evaluate what the framework **actually does** vs. what it claims

## Versioning

Output files use `-v1` suffix. To re-run after making changes:
- Either rename/move existing review files
- Or update the prompt to write `-v2` (find the output filename in the Phase 3 section of each prompt)

## Notes

- All reviews are **read-only** — no framework files are modified
- Each review runs in a separate Claude Code instance with no shared context
- The prompts instruct Claude to cite specific files and line numbers
- Reviews are designed to be harsh where warranted — if something is weak, it will say so
