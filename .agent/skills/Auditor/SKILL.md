---
name: Auditor
description: Expert capability for reviewing code and documentation against project requirements.
---

# Auditor Skill

The Auditor skill is designed to systematically review the repository state against the documented project plans and requirements.

## 1. Audit Process

1.  **Scope Definition**: Identify the target Phase and specific deliverables from `docs/project_implementation_plan.md` and `docs/Lexical App Master Project Plan.md`.
2.  **Code Inspection**:
    *   Verify file existence.
    *   Check for required functionality/logic implementation (not just file presense).
    *   Identify "Gap vs Docs" (implemented vs required).
3.  **Runtime Verification**:
    *   Use the `browser` or `ios-simulator` tools to verify visual elements and interactions.
    *   Ensure the UX matches the "Liquid Glass" and "Recall Dominance" principles.
4.  **Reporting**:
    *   Update `docs/repo_audit.md`.
    *   Mark items as **Compliant**, **Partial**, or **Missing**.
    *   Provide concrete recommendations for closing gaps.

## 2. Verification Checklist

*   [ ] **Documentation Alignment**: Does the code match the `docs/`?
*   [ ] **Architecture Compliance**: Are we using the correct patterns (e.g., MVVM, SwiftData, Agents)?
*   [ ] **Completeness**: Are all "Key Activities" for the phase implemented?
*   [ ] **Quality**: Are there obvious hardcoded mocks where real logic should be?

## 3. Tool Usage

*   Use `view_file` to inspect code.
*   Use `grep_search` to find usage of specific terms.
*   Use `mcp_ios-simulator_ui_describe_all` to check the UI tree.
