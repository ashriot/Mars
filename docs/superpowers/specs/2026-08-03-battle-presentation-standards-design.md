# Battle Presentation Standards Documentation Design

## Status

Approved on 2026-08-03.

## Goal

Give future agents a concise, current starting point for battle presentation work without requiring them to reconstruct durable UX and 3D art-direction decisions from historical feature specs.

## Structure

Create two active standards under `docs/standards/`:

- `battle_ux.md` covers visual hierarchy, active and inactive emphasis, controller and pointer parity, responsive layout, projected enemy HUDs, targeting feedback, and visual acceptance.
- `battle_3d_presentation.md` covers the first-person shoebox/diorama composition, enemy formations, model readability, scene ownership, lighting, camera motion, effects, and visual acceptance.

Each document stays short and task-oriented. Use compact principles plus `Do`, `Avoid`, and `Verify` guidance where that structure improves scanning. Link to detailed feature specs for background rather than repeating their implementation history.

## Authority and durability

The standards describe current project intent, ownership boundaries, required behavior, and acceptance criteria. They do not freeze scene-specific tuning such as exact pixel dimensions, formation coordinates, light energies, exposure values, or animation timing. Those values remain in editable scenes, resources, tests, or the feature spec that introduced them.

If a later approved design changes a standard, update the active standard in the same effort. Historical design records remain unchanged unless they contain a factual link or status error.

## Discovery

- Add both standards to `docs/README.md` under Design and Engineering.
- Add direct links near the top of `AGENTS.md`, beside the existing coordinate-space guidance, so agents see them before editing battle UI or 3D scenes.
- Keep `AGENTS.md` limited to pointers; put presentation guidance in the focused documents.

## Scope

This is documentation-only. It does not change scenes, lighting, UI geometry, controller behavior, combat rules, or tests. Verification consists of link checks, a placeholder and contradiction review, and `git diff --check`.
