# Project Documentation

Use this page as the index for project knowledge that is more detailed or more likely to change than the root agent guidance.

## Development and Testing

- [Automated testing](testing/README.md) — Supported Godot and GUT versions, isolated test commands, and accepted diagnostics.
- [CTB combat checklist](testing/ctb-combat-checklist.md) — Manual acceptance for the combat timeline rail, previews, and action recovery.
- [Controller checklist](testing/controller-manual-checklist.md) — Manual controller and keyboard/mouse verification across the playable loop.
- [Dungeon checklist](testing/dungeon-manual-checklist.md) — Manual dungeon traversal, interaction, save, and restoration checks.
- [Starting role kit checklist](testing/starting-role-kit-checklist.md) — Manual validation for role anchors, starting skills, and progression trees.

## Design and Engineering

- [Coordinate spaces and positioning](coordinate-spaces.md) — Authoritative world, viewport, UI, cursor, reticle, and camera conversion rules.
- [Refactor notes](refactor.md) — Research and candidates for the later refactor phase.
- [CTB recovery and deterministic timing](superpowers/specs/2026-07-15-ctb-recovery-and-horizontal-queue-design.md) — Authoritative deterministic and normalized CT and action-recovery design.
- [CTB scrollable rail animation](superpowers/specs/2026-07-15-ctb-scrollable-rail-animation-design.md) — Superseding current rail presentation and animation design.
- [Combat target presentation](superpowers/specs/2026-07-14-combat-target-presentation-design.md) — Current hero/enemy target availability, selection, CTB preview, and input behavior.
- [Controller-driven scan cursor](superpowers/specs/2026-07-14-controller-driven-scan-cursor-design.md) — Historical initial controller scan-pointer and edge-scroll design.
- [Terminal-to-scan correction](superpowers/specs/2026-07-14-terminal-scan-transition-correction-design.md) — Current terminal shortcut, modal transition, world-aim cursor, and scan-camera behavior.
- [Design records](superpowers/specs/) — Approved feature designs and decisions captured before implementation.
- [Implementation plans](superpowers/plans/) — Task-level execution records for larger changes.

Design records and implementation plans describe the work at the time it was performed; confirm their assumptions against current code and active topic documentation.

## Product Knowledge

Record evolving UX preferences, gameplay rules, architecture decisions, progression behavior, and content guidance in focused Markdown files under `docs/`. Add a one-line link here whenever a new topic document becomes authoritative.
