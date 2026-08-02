# Project Documentation

Use this page as the index for project knowledge that is more detailed or more likely to change than the root agent guidance.

## Development and Testing

- [Automated testing](testing/README.md) — Supported Godot and GUT versions, isolated test commands, and accepted diagnostics.
- [Curated local Quaternius assets](assets/quaternius-local-assets.md) — Local-only CC0 battle-model installation, exact manifest, and Git-safety checks.
- [CTB combat checklist](testing/ctb-combat-checklist.md) — Manual acceptance for the combat timeline rail, previews, and action recovery.
- [Controller checklist](testing/controller-manual-checklist.md) — Manual controller and keyboard/mouse verification across the playable loop.
- [Dungeon checklist](testing/dungeon-manual-checklist.md) — Manual dungeon traversal, interaction, save, and restoration checks.
- [Endgame battle lab checklist](testing/endgame-battle-lab-checklist.md) — Direct-launch workflow, deterministic presets, combat observations, and the benchmark-content gate.
- [Starting role kit checklist](testing/starting-role-kit-checklist.md) — Manual validation for role anchors, starting skills, and progression trees.

## Design and Engineering

- [Coordinate spaces and positioning](coordinate-spaces.md) — Authoritative world, viewport, UI, cursor, reticle, and camera conversion rules.
- [Refactor notes](refactor.md) — Research and candidates for the later refactor phase.
- [Steam Deck responsive UI](superpowers/specs/2026-07-15-steam-deck-responsive-ui-design.md) — Project-wide native `1280x800` handheld and `1920x1080` desktop resolution design.
- [Hub controller navigation](superpowers/specs/2026-07-16-hub-controller-navigation-design.md) — Controller-first party-management tabs, hero/content depth, pulsing focus, and chrome presentation.
- [CTB recovery and deterministic timing](superpowers/specs/2026-07-15-ctb-recovery-and-horizontal-queue-design.md) — Authoritative deterministic and normalized CT and action-recovery design.
- [CTB scrollable rail animation](superpowers/specs/2026-07-15-ctb-scrollable-rail-animation-design.md) — Superseding current rail presentation and animation design.
- [Combat target presentation](superpowers/specs/2026-07-14-combat-target-presentation-design.md) — Current hero/enemy target availability, selection, CTB preview, and input behavior.
- [Battle damage architecture](superpowers/specs/2026-07-17-battle-damage-architecture-design.md) — Authoritative damage math, contextual scaling, extension boundaries, presentation, and verification design.
- [Endgame enemy AI and combat benchmark](superpowers/specs/2026-07-18-endgame-enemy-ai-benchmark-design.md) — Cooldown-driven enemy decisions, reusable combat extensions, max-party battle lab, and endgame benchmark encounters.
- [Endgame full hero kits](superpowers/specs/2026-07-18-endgame-full-hero-kits-design.md) — Benchmark-only complete authored role kits with tier-5, rank-30 equipment and unchanged campaign progression.
- [First-person 3D battle presentation](superpowers/specs/2026-08-01-first-person-3d-battle-presentation-design.md) — Authoritative combatants, 3D enemy units, projected HUDs, first-person effects, formations, camera behavior, and migration boundaries.
- [Local 3D battle slice](superpowers/specs/2026-08-02-local-3d-battle-slice-design.md) — Curated local-only Quaternius assets, EyeDrone reuse, industrial room composition, optional loading, formations, projected HUDs, and verification.
- [Controller-driven scan cursor](superpowers/specs/2026-07-14-controller-driven-scan-cursor-design.md) — Historical initial controller scan-pointer and edge-scroll design.
- [Terminal-to-scan correction](superpowers/specs/2026-07-14-terminal-scan-transition-correction-design.md) — Current terminal shortcut, modal transition, world-aim cursor, and scan-camera behavior.
- [Design records](superpowers/specs/) — Approved feature designs and decisions captured before implementation.
- [Implementation plans](superpowers/plans/) — Task-level execution records for larger changes.

Design records and implementation plans describe the work at the time it was performed; confirm their assumptions against current code and active topic documentation.

## Product Knowledge

Record evolving UX preferences, gameplay rules, architecture decisions, progression behavior, and content guidance in focused Markdown files under `docs/`. Add a one-line link here whenever a new topic document becomes authoritative.
