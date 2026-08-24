# Repository Guide

## Project

Redshift is a local, pre-alpha game prototype built with Godot 4.7.1. Optimize for safe iteration and clear behavior; there are no public-release or backward-compatibility guarantees yet.

- `src/` — Gameplay systems, UI, scenes, shaders, and runtime scripts.
- `data/` — Authored heroes, roles, progression trees, actions, encounters, equipment, and theme resources.
- `assets/` — Source graphics, glyphs, cursors, music, and sound effects.
- `test/` — GUT unit and integration coverage.
- `docs/` — Testing guidance, manual checklists, design decisions, plans, and refactor research.
- `addons/` — Vendored Godot plugins; GUT is currently the supported test framework.

Project documentation: [`docs/README.md`](docs/README.md).

Positioning and coordinate-space guidance: [`docs/coordinate-spaces.md`](docs/coordinate-spaces.md).

## Working Rules

- Inspect neighboring scripts, scenes, data, tests, and documentation before changing behavior.
- Preserve unrelated user work in a dirty worktree; do not rewrite, restore, stage, or commit files outside the task.
- Make the smallest cohesive change that solves the problem; refactor locally only when it directly improves the change.
- Do not add speculative save migrations, backward compatibility, release hardening, or public-install support unless requested.
- Ask before changing the Godot version, vendored plugins, dependencies, project-wide formats, or durable architecture.
- Use ordinary feature branches in the primary checkout by default; do not create or use Git worktrees unless the user explicitly requests one for that effort.
- When committing, include only task files plus any required Godot sidecars generated for those files.

## Godot Files

- Use Godot 4.7.1 at `/Applications/Godot 4.7.app/Contents/MacOS/Godot` unless the user explicitly approves another version. The prior 4.6.3 iPhone verification does not establish 4.7.1 iOS visual acceptance, which must be re-run separately.
- Preserve and commit required `.uid` and `.import` sidecars; do not discard them as generated noise or manually normalize incidental generated fields.
- Treat `.godot/` as a local cache and never commit it.
- Use lowercase snake_case for new files and directories where practical; do not perform unrelated bulk renames.
- Treat `.tscn`, `.tres`, `.gd`, `.gdshader`, JSON, and other text resources as source code and keep edits reviewable.

## Godot 3D References

Use the installed skills before changing the corresponding rendering systems:

- `godot-3d-lighting` for Mobile/Forward+ light budgets, shadows, environment lighting, and GI decisions. Source: <https://github.com/thedivergentai/GD-Agentic-Skills/tree/main/skills/godot-3d-lighting>.
- `godot-3d-materials` for `StandardMaterial3D`, imported PBR textures, metallic/roughness workflows, and runtime material overrides. Source: <https://github.com/thedivergentai/GD-Agentic-Skills/tree/main/skills/godot-3d-materials>.
- `godot-3d-world-building` for room/level geometry, `WorldEnvironment`, and world-presentation work. Source: <https://github.com/thedivergentai/GD-Agentic-Skills/tree/main/skills/godot-3d-world-building>.

When a local GLTF replaces a scene placeholder through `OptionalLocalModel3D`, inspect the runtime imported material before tuning the placeholder resource.

## Testing

Testing instructions: [`docs/testing/README.md`](docs/testing/README.md).

- The isolated `HOME` documented there is mandatory for automated Godot runs; never allow tests to read or write ordinary local save data.
- Use explicit test storage overrides or temporary directories for every save-related test, and restore any fixture state during teardown.
- Run focused tests while iterating, then scale final verification to the risk and reach of the change.
- Run the complete suite for cross-cutting runtime, save, progression, navigation, input, or scene changes.
- Treat test and assertion totals as diagnostics, not targets; coverage quality and distinct protected behavior matter more than raw counts.
- Add automated coverage for gameplay rules, state transitions, persistence, softlocks, and observed regressions; prefer assertions at public behavior boundaries over private implementation details.
- Avoid duplicate integration scenarios and brittle timing assertions; consolidate overlapping coverage during refactors instead of growing the suite indefinitely.
- Use the relevant manual checklist for visual, controller, touch, scene-transition, or full-loop behavior that automation cannot establish.
- Prefer manual acceptance for control feel, animation polish, and purely visual presentation unless a stable automated seam protects meaningful behavior.
- Expected test errors and documented engine shutdown diagnostics are acceptable only when assertions pass and the process exits successfully; parser errors, crashes, and unexpected failures are not.

## Documentation

- Keep this file limited to durable repository workflow and safety rules.
- Record evolving UX preferences, gameplay rules, balance choices, architecture decisions, and content guidance in focused files under `docs/`.
- Add new authoritative documents to [`docs/README.md`](docs/README.md) with a one-line description.
- Update relevant documentation when a change invalidates a documented behavior, constraint, checklist, design, or refactor note.
- Treat old design records and implementation plans as historical context; verify them against current code and active documentation.

## Workflow Depth

- Use Superpowers for substantial design, planning, complex debugging, architectural decisions, or multi-step implementation where its process materially improves the outcome.
- For small, well-scoped changes, use the normal workflow: inspect local context, make the minimal edit, run focused verification, and report the result.
- Do not create design specs or implementation plans for routine edits with an obvious scope and outcome.

## Handoff

- Summarize the behavior or documentation changed, not merely the commands run.
- Report automated verification with exact pass/fail results and distinguish remaining manual checks.
- Call out meaningful warnings, assumptions, deferred work, and any files intentionally left uncommitted.
- Never claim a fix is complete without fresh verification proportional to the change.
