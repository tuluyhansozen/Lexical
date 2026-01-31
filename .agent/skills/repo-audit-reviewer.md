# Skill: Repository Audit Reviewer

## Description
Guides audits of repository changes against documented project phases, ensuring deliverables and tooling configurations align with the project plan.

## 1. Audit Scope Definition
- **Docs First:** Read project plan and phase requirements before reviewing code.
- **Phase Focus:** Verify presence and intent of listed deliverables for the targeted phase.
- **Configuration Review:** Validate `.agent/` assets and MCP configuration paths.

## 2. Evidence Gathering
- **File Existence:** Confirm required files and directories are present.
- **Implementation Fit:** Validate that the implementation matches the documented approach (e.g., TextKit 2 vs. legacy views).
- **Risk Notes:** Flag gaps that can cause functional divergence (e.g., lemma-to-surface mismatches).

## 3. Reporting Standards
- **Compliant Items:** List verified deliverables with short evidence notes.
- **Gaps & Risks:** List any mismatch to docs or missing artifacts.
- **Recommendations:** Provide actionable fixes ordered by impact.

## 4. Non-Goals
- Do not refactor unrelated code.
- Do not add new product requirements outside the documented plan.
