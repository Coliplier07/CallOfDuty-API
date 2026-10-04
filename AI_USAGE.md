# AI Usage Log

This file documents AI-assisted development performed on the COD Stats project.

The goal is transparency: AI may assist with planning, documentation, code generation, debugging, and review, but project contributors remain responsible for understanding and validating the final implementation.

## Entry Format

Each entry should include:

- **Date**
- **Area**
- **AI Tool**
- **Task / Prompt**
- **Changes Made**
- **Human Review**
- **Result**

---

## 2026-10-04 — Repository Foundation

**Area:** Project structure and documentation

**AI Tool:** ChatGPT

**Task / Prompt:** Create the initial GitHub repository structure for a Call of Duty statistics application. Establish the API/mobile monorepo layout, README, AI usage log, environment template, and CI pipeline.

**Changes Made:**
- Created `apps/api` for the Node.js/TypeScript REST API.
- Created `apps/mobile` for the future Expo/React Native application.
- Added `.github/workflows/ci.yml`.
- Added `.env.example`.
- Added `.gitignore`.
- Added initial project documentation.
- Defined branching and Conventional Commit guidelines.

**Human Review:** Required before merge. Repository structure, workflow configuration, and documentation should be reviewed by the project owner.

**Result:** Initial repository foundation created.
