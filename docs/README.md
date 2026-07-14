# Project Documentation

Use this page as the index for project knowledge that is more detailed or more likely to change than the root agent guidance.

## Development and Testing

- [Automated testing](testing/README.md) — Supported Godot and GUT versions, isolated test commands, and accepted diagnostics.
- [Controller checklist](testing/controller-manual-checklist.md) — Manual controller and keyboard/mouse verification across the playable loop.
- [Dungeon checklist](testing/dungeon-manual-checklist.md) — Manual dungeon traversal, interaction, save, and restoration checks.
- [Starting role kit checklist](testing/starting-role-kit-checklist.md) — Manual validation for role anchors, starting skills, and progression trees.

## Design and Engineering

- [Refactor notes](refactor.md) — Research and candidates for the later refactor phase.
- [Controller-driven scan cursor](superpowers/specs/2026-07-14-controller-driven-scan-cursor-design.md) — Authoritative mouse/controller scan pointer, hover selection, and edge-scroll behavior.
- [Design records](superpowers/specs/) — Approved feature designs and decisions captured before implementation.
- [Implementation plans](superpowers/plans/) — Task-level execution records for larger changes.

Design records and implementation plans describe the work at the time it was performed; confirm their assumptions against current code and active topic documentation.

## Product Knowledge

Record evolving UX preferences, gameplay rules, architecture decisions, progression behavior, and content guidance in focused Markdown files under `docs/`. Add a one-line link here whenever a new topic document becomes authoritative.
