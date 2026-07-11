# Progression Redesign Task 6 Report

## Status

DONE

## Implementation

- Converted all nine role progression trees to schema-version-1 JSON under `data/progression/<hero>/`.
- Authored stable semantic node IDs (`<role>.root`, resource names, and deterministic suffixes for repeated stat rewards), with explicit parent, rank, column, XP cost, and typed effect data.
- Preserved the complete authored Gunner, Sniper, Kineticist, Psion, Medic, Strategist, and Vanguard topology and reward data.
- Added recursive, deterministic JSON discovery to `ProgressionCatalog` so the hero subdirectories load transactionally from `res://data/progression/`.
- Added the `ProgressionSystem` startup composition root. It publishes catalog/service only after every file validates, and reports every content error on failure.
- Registered `ProgressionSystem` before gameplay autoload consumers and injected its catalog/service into `PartyMenu` by default.
- Marked legacy `RoleDefinition.root_node` and `init_structure()` as deprecated, legacy-only compatibility. JSON is operationally authoritative: all new progression runtime, service, startup, and hub consumers resolve `RoleDefinition.role_id` through the catalog and a guard test prevents them from accessing legacy topology. Task 7 removes the retained legacy fields, traversal, and resources after migration.
- Did not edit or stage the user's dirty hub scenes or other unrelated files.

## Strict TDD Evidence

RED was observed with the new production-content test before JSON/startup implementation: all nine files were missing, recursive catalog load returned no roles, the startup autoload was absent, and PartyMenu dependencies were null.

GREEN verification:

- Production content plus full GUT suite: 138/138 tests passed, 1,759 assertions.
- All nine JSON documents parsed successfully with `jq -e`.
- Headless Godot editor parse completed with exit code 0.
- `git diff --check` completed with no whitespace errors.

Follow-up review verification adds:

- Node-by-node parity for all seven complete legacy trees: every parent edge, rank, visual column, XP cost, effect type, stat/amount, exact resource path, and action slot.
- Explicit approved-baseline checks for the single-root Operative and Dominator trees.
- Exact nine-role startup/catalog ID-set checks and Action resource-class checks.
- A deterministic nested-directory open-failure test proving diagnostics and preservation of the previously committed catalog.
- A legacy-topology access guard over new progression and hub consumers.

The macOS Godot process emits its existing system certificate lookup diagnostic; it did not affect exit status, parsing, or tests.

## Content Summary

| Role | Nodes | Total XP | Root reward |
|---|---:|---:|---|
| gun | 18 | 13,900 | Double Tap |
| snp | 8 | 3,300 | Mark Target |
| opr | 1 | 100 | Inspire |
| kin | 17 | 12,550 | Telekinesis |
| psi | 18 | 13,150 | Focused Bolt |
| dom | 1 | 100 | Displace |
| med | 6 | 2,100 | Immunize |
| stg | 6 | 2,100 | Direct |
| van | 6 | 2,100 | Draw Fire |

## Conversion Concerns

- Operative currently contains only its confirmed `Inspire` action root. The legacy RoleNode explicitly authored `unlock_resource = inspire.tres`, although the current legacy RoleDefinition action array is empty and current traversal no longer consumes that old property.
- Dominator had combat-kit metadata but no legacy progression root. Per confirmed authored intent, its valid JSON currently contains only the `Displace` action root.
- No additional Operative or Dominator nodes were invented. Both trees remain intentionally single-node until more progression content is authored.
- Legacy generated IDs are intentionally not retained; stable semantic JSON IDs are the new persisted identity.
- Task 6 deliberately retains `RoleDefinition.root_node`/`init_structure()` because existing pre-migration `HeroData` still needs them. Task 7 is the planned deletion boundary; removing them in Task 6 would break the staged migration. No duplicate progression ID was added.

## Commit

`feat: load role progression from json`
