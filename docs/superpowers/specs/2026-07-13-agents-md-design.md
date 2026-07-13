# Repository Agent Guidance Design

## Purpose

Create a concise root `AGENTS.md` that tells coding agents how to work safely and effectively in this repository without duplicating changing project documentation.

## Information Boundary

`AGENTS.md` contains durable engineering constraints, repository workflow, and links to authoritative documentation. Gameplay behavior, UX preferences, architecture research, balance decisions, and other evolving product knowledge belong under `docs/`.

## Structure

The root guidance will contain these short sections:

- **Project:** Identify the project as a local pre-alpha Godot 4.6.3 prototype and summarize the major source, data, test, asset, and documentation directories.
- **Documentation:** Point to a central `docs/README.md` index and require changing design knowledge to be recorded in the relevant documentation rather than copied into `AGENTS.md`.
- **Working Rules:** Require inspection before edits, preservation of unrelated work, scoped changes, and no speculative save migration or backward-compatibility work unless requested.
- **Godot Rules:** Preserve required `.uid` and `.import` sidecars, exclude `.godot/` cache contents, and use lowercase snake_case names for new files and directories where practical.
- **Testing:** Point to `docs/testing/README.md`, require the isolated test `HOME`, protect real save-slot data, and scale verification to the risk of the change.
- **Workflow:** Reserve Superpowers for substantial design, planning, debugging, or multi-step efforts; use focused inspection, implementation, and verification for small changes.
- **Handoff:** Report changed files, automated verification, outstanding manual checks, and meaningful known warnings.

## Documentation Index

Add `docs/README.md` as the stable destination linked from `AGENTS.md`. It will use one-line entries to route agents to testing instructions, manual checklists, refactor research, validated designs, and implementation plans. It may later link to dedicated UX, architecture, progression, or content documents without requiring changes to the root agent guidance.

## Style

Keep both files skimmable. Prefer direct requirements and single-line pointers over explanations, repeated commands, or detailed product decisions. Every linked path must exist when introduced.

## Acceptance Criteria

- An agent can quickly identify the engine version, safe test workflow, generated-file policy, prototype compatibility stance, and expected handoff.
- Detailed commands and changing project decisions have one authoritative home under `docs/`.
- The guidance explicitly prevents automated tests from touching ordinary local save data.
- Existing unrelated working-tree changes remain untouched.
