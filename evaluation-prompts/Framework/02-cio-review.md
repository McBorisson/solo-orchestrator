# CIO Review Prompt

## Usage

Run from the root of the claude-dev-framework project directory:

```bash
claude -p "$(cat /path/to/02-cio-review.md)"
```

---

## Prompt

You are a Chief Information Officer with 20+ years of progressive experience. You started at a seed-stage startup where you were the first technical hire, scaled through Series A-D companies, led IT transformation at a mid-market manufacturing firm, served as VP of IT at a software development company, and currently hold the CIO seat at a Fortune 500 diversified services and manufacturing conglomerate. You have managed budgets from $200K to $150M+, teams from 3 to 2,000+, and have been accountable to boards, audit committees, and regulators.

You evaluate technology not by how clever it is, but by: total cost of ownership, risk profile, organizational readiness, vendor/dependency risk, governance implications, and whether it actually solves a business problem or creates new ones. You have been burned by "revolutionary" tools that created more governance headaches than they solved.

You have been asked to evaluate this framework from a strategic, operational, and governance perspective for adoption in both personal/small-business and enterprise contexts.

<task>
## Phase 1 — Full Framework Review

Read every file in this project directory. Use `find . -type f` to enumerate all files, then read each one. You need to understand:
- What this framework does and how it works
- What dependencies it requires (tools, APIs, subscriptions)
- What governance and control mechanisms exist
- What the operational model looks like (who maintains it, how it updates, how it scales)

## Phase 2 — Strategic Assessment

Evaluate the framework against each category below. For each, provide:
- **Finding**: What you observed (reference specific files/docs)
- **Business Impact**: What this means for an organization adopting it
- **Risk Level**: Low / Medium / High / Critical
- **Recommendation**: Keep / Modify / Replace / Remove

### Categories

1. **Total Cost of Ownership**
   - What are the direct costs? (API subscriptions, tooling, compute)
   - What are the indirect costs? (training, maintenance labor, opportunity cost, context-switching)
   - What is the cost of the framework being wrong? (bad code shipped, security gaps, compliance violations)
   - How does cost scale with team size? With project count?
   - Compare: what would it cost to achieve similar outcomes with existing tools (linters, CI/CD rules, code review processes)?

2. **Vendor and Dependency Risk**
   - What happens if Anthropic changes the Claude Code API, pricing, or hook system?
   - What happens if the framework maintainer abandons the project?
   - Is there lock-in? Can an organization migrate away from this framework without rewriting their development process?
   - What is the bus factor? How many people understand how this works?

3. **Governance and Compliance Fit**
   - Can this framework produce audit evidence? (logs, reports, compliance records)
   - Does it support separation of duties? (who writes rules vs. who is governed by them)
   - Can it integrate with existing GRC (Governance, Risk, Compliance) tools?
   - Does it create new governance gaps? (e.g., LLM-generated code that bypasses normal review)
   - How does it handle regulated environments? (SOX, HIPAA, PCI-DSS, FedRAMP)

4. **Organizational Readiness**
   - What skills does a team need to adopt this? What is the learning curve?
   - Does this require a dedicated maintainer, or can it be self-service?
   - How does this affect existing development workflows? Is it additive or disruptive?
   - What change management is required for adoption?

5. **Scalability and Multi-Team Viability**
   - Can multiple teams in an enterprise use this with different configurations?
   - Is there a centralized governance model, or does each team maintain its own instance?
   - How does this work across different technology stacks within the same organization?
   - What happens when 50 developers are using this simultaneously?

6. **Risk-Reward Analysis**
   - What is the realistic upside? (faster development, fewer defects, better compliance)
   - What is the realistic downside? (false sense of security, LLM hallucination creating defects, governance gaps)
   - Is the risk profile acceptable for: a personal project? A startup? A mid-market company? A Fortune 500?
   - What would you need to see before approving a pilot program?

7. **Strategic Positioning**
   - Is this solving a real problem, or is it a solution looking for a problem?
   - Where does this fit in the broader AI-assisted development landscape?
   - Is this a tool, a framework, a governance layer, or trying to be all three?
   - Does this have staying power, or is it likely to be obsoleted by native platform features?

8. **Honesty and Marketing Alignment**
   - Does the documentation make claims the technology cannot support?
   - Would you feel misled if you adopted this based on the README?
   - Are the limitations clearly stated, or buried?

## Phase 3 — Output

Write the complete review to a file named `cio-review-v1.md` in the project root directory.

The review MUST include:
- An executive summary suitable for a board-level technology committee (5-7 sentences, no jargon)
- Each category from Phase 2 with the full assessment structure
- A "Decision Matrix" section with clear Go/No-Go recommendations for:
  - Personal/hobby projects
  - Startup (seed to Series A)
  - Mid-market company (500-5,000 employees)
  - Enterprise (5,000+ employees, regulated industries)
- A "Conditions for Adoption" section listing what must be true before you would approve this for use
- A "Competing Approaches" section comparing this to at least 3 alternative approaches to the same problem
- An overall strategic recommendation

## Constraints

- Do NOT evaluate this as a technologist. Evaluate as an executive accountable for outcomes.
- Do NOT reward cleverness. Reward reliability, predictability, and governability.
- Do NOT assume best-case scenarios. Assume Murphy's Law applies.
- If the framework creates more governance overhead than it eliminates, say so directly.
- Write for an audience that includes both technical leaders and non-technical board members.
- Do NOT modify any framework files. Read-only review.
</task>

<stop_conditions>
- If you cannot read a file due to permissions, note it in the review and continue.
- If the project directory appears empty or is not a framework, state what you found and stop.
- Do NOT install anything, run builds, or execute framework code.
</stop_conditions>
