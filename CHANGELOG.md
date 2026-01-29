# Lexical Project Changelog

## [2026-01-29]
### Milestone 1: Foundation & Environment Setup
- **Agent Infrastructure:** Initialized `.agent` directory with Rules (Architect, Engineer, QA) and Skills (FSRS, UI, Sync, Reader).
- **Tooling:** Installed and configured `uv` for high-performance Python script execution.
- **MCP Setup:** Configured `mcp_config.json` for iOS Simulator integration.
- **Verification:** Created and executed `verify_env.py` to validate the agentic environment.
- **Build Fixes:** Resolved compilation errors in `Colors.swift` and performed project-wide cleanup of legacy logs.

### Project Rebranding & Refactoring
- **Renaming:** Rebranded project from `SonApp` to `Lexical`. Renamed root directory and all internal references.
- **App Structure:** Renamed source files to match the new `Lexical` identity and updated Bundle ID to `com.lexical.Lexical`.
- **Build Scripts:** Updated `run_sim.sh` and `mcp_config.json` to reflect the new directory structure.
- **Documentation:** Created this `CHANGELOG.md` to track project evolution.
