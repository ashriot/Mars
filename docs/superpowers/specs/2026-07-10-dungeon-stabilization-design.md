# Dungeon Crawl Stabilization Design

**Date:** 2026-07-10
**Status:** Approved for implementation planning

## Purpose

Stabilize the existing dungeon crawl prototype before adding content or performing a broad architectural refactor. The work should make run completion, node resolution, map generation, terminals, and save/resume behavior deterministic and testable.

This is a local, pre-alpha prototype. Existing active dungeon saves do not need migration support. Permanent player progression should remain intact, but an incompatible in-progress run may be rejected or cleared safely.

## Scope

The stabilization pass includes:

- Correct Success, Retreat, and Defeat flows.
- Correct boss victory and terminal extraction behavior.
- Make run completion idempotent so rewards and exit signals occur once.
- Give node interactions explicit completion, cancellation, run-ending, and error outcomes.
- Restore saved maps from saved node types and payloads rather than regenerated randomness.
- Correct dungeon tier initialization and tier-based scaling.
- Correct profile multiplier and terminal-count calculations.
- Make progress totals agree with generated actionable nodes.
- Validate terminal, reward, and encounter payloads before using them.
- Correct terminal numbering, cancellation, consumption, and medical behavior.
- Establish automated regression coverage and a manual crawl checklist.
- Record concrete future refactor candidates in `docs/refactor.md` as they are discovered.

The stabilization pass explicitly excludes:

- Event node content.
- New consequences for reaching 100% Alert.
- New terminal protocols or dungeon content.
- Broad restructuring of `DungeonMap`, `GameManager`, or the scene tree.
- Compatibility migration for existing active-run saves.

## Delivery Strategy

Use behavior-first stabilization:

1. Characterize important rules and state transitions with tests.
2. Fix one complete gameplay flow at a time.
3. Run focused and full tests after every behavioral slice.
4. Complete a manual crawl verification after automated checks pass.
5. Refactor separately under the protection of the passing stabilization suite.

During stabilization, structural changes are allowed only when a narrow extraction is necessary for correctness or testability. Examples include a guarded `finish_run(result)` method or a pure node-count helper. General cleanup is deferred.

## Existing Responsibilities

The current high-level ownership remains in place:

- `GameManager` coordinates node interactions, battle transitions, terminal choices, and run-ending presentation.
- `DungeonMap` owns map generation, traversal state, visibility, Alert, node state, and map serialization.
- `RunManager` owns temporary run rewards, run persistence, and reward commitment.
- `Terminal` owns terminal presentation and emits the selected protocol or close action.

The stabilization work should not introduce a new global manager or replace this scene structure.

## Run-Ending Boundary

All run-ending causes must route through one guarded transition:

| Trigger | Result |
|---|---|
| Enter Exit | Success |
| Win boss encounter | Success |
| Extract from Entrance | Retreat |
| Extract from terminal | Retreat |
| Party defeat | Defeat |

The transition must:

1. Ignore repeated requests after ending has begun.
2. Lock map interaction.
3. Remove or close transient node content without deleting the result screen.
4. Create exactly one result screen.
5. Commit rewards exactly once when the player confirms the result.
6. Emit the dungeon exit exactly once.

Terminal extraction must return immediately from terminal-choice handling and must not fall through to ordinary node completion cleanup. Boss victory must enter the Success flow directly instead of returning control to a completed boss node.

## Node-Resolution Boundary

Every node interaction finishes with one of four semantic outcomes:

- `COMPLETED`: consume the node, update visibility and counters, autosave, and return map control.
- `CANCELED`: preserve the node, do not mark it completed, and return map control.
- `RUN_ENDED`: transfer control to the guarded run-ending flow; do not perform ordinary node cleanup afterward.
- `ERROR`: report a contextual error, preserve the node for retry when possible, and recover map control safely.

The implementation may represent these outcomes with an enum or narrowly scoped methods. It should not rely on ambiguous booleans whose meaning changes by caller.

## Defensive Payload Handling

Encounter, reward, and terminal payloads must be validated before indexing, duplicating, or applying them.

- A missing encounter assignment or unknown encounter ID leaves the node retryable and logs its coordinates and invalid value.
- A missing reward payload leaves the node retryable rather than consuming it as empty loot.
- A missing terminal payload leaves the node retryable.
- Invalid active-run save data is rejected safely. Because active-run compatibility is not required, the game may clear the active run and return to a safe entry point while preserving permanent progression.

Prototype errors should be loud enough to diagnose without turning malformed data into silent player progress loss.

## Save and Resume

The saved node map is authoritative. Restore must rebuild a coordinate-to-type dictionary from each saved node's `type` field and pass it into grid construction. It must then restore:

- Current coordinates.
- Node type, visibility, awareness, visit, and completion state.
- Current Alert and derived vision state.
- Terminal payloads.
- Encounter assignments.
- Reward payloads.
- Run Bits, XP, inventory, equipment, and mods.
- Progress totals.

Alert must be restored before any visibility update so a high-Alert resume cannot reveal extra nodes using a default vision range.

Seeded generation remains useful for new runs and deterministic tests, but resume correctness must not depend on replaying the random call sequence.

## Generation and Tier Rules

Node density and dungeon profile multipliers must be applied exactly once. Forced minimums or additional nodes must be applied before calculating `total_nodes` and loader progress totals.

Generation verification must establish these invariants:

- One Entrance exists.
- One Exit or Boss endpoint exists.
- The configured minimum terminal count is represented in both the map and totals.
- Generated payload dictionaries correspond to nodes of the matching type.
- `total_nodes` uses one documented definition and matches the HUD progress denominator.
- Identical seeds and configuration produce identical new-run layouts.

Fresh runs should begin at dungeon tier 1 unless an explicit profile or mission selection supplies another tier. Tier-based encounter filtering and loot scaling should use that value consistently.

## Terminal Behavior

Each terminal remains retryable until a protocol is successfully selected.

- Closing the terminal produces `CANCELED`.
- Canceling scan targeting reopens the same terminal without consuming it.
- Completing a scan consumes the terminal once.
- Security, Medical, and Finance apply their effect once and consume the terminal.
- Extraction produces `RUN_ENDED` and does not complete or autosave through the normal node path.
- Displayed option numbers are unique and agree with the available protocol links.

Medical behavior must be encoded explicitly and protected with tests:

| Hero state | Standard Medical | Upgraded Medical |
|---|---|---|
| Injured | Clear injuries | Clear injuries and grant one random boon |
| Uninjured | Grant one random boon | Grant both boons |

Random medical outcomes should accept controlled randomness in tests so assertions remain deterministic.

## Testing Strategy

The verified test environment uses the official GUT `godot_4_7` branch snapshot at runtime version 9.7.1 and runs automated tests with Godot 4.7, while production project metadata remains Godot 4.6. See `addons/gut/VENDORED.md` for the pinned source and harness details. Tests should focus on rules, state transitions, and serialization rather than animation timing, audio playback, or exact visual presentation.

### Pure rule coverage

- Profile multipliers are applied once.
- Forced terminal counts are included in totals.
- Tier and loot scaling start at the intended tier.
- Reward retention is correct for Success, Retreat, and Defeat.
- Medical outcomes match the behavior table.

### State-flow coverage

- Exit produces Success exactly once.
- Boss victory produces Success exactly once.
- Terminal extraction produces Retreat without deleting its result screen.
- Entrance extraction produces Retreat.
- Party defeat produces Defeat.
- Closing a terminal preserves it.
- Canceling a scan reopens the terminal.
- Selecting a terminal protocol completes it once.
- Missing payloads report an error and preserve their node.

### Persistence coverage

- Save/restore round-trips coordinates, node types, states, Alert, payloads, and run rewards.
- High-Alert resume does not reveal additional nodes.
- Restore does not depend on rerunning procedural generation.
- Invalid prototype active-run data fails safely without damaging permanent progression.

### Verification cadence

For each behavioral slice:

1. Write or update a focused failing test.
2. Confirm the test fails for the expected reason.
3. Implement the smallest behavioral correction.
4. Run the focused test.
5. Run the full suite.
6. Commit the self-contained slice.

At the end of stabilization:

- Run the complete test suite headlessly.
- Launch the project and check for parse and runtime errors.
- Complete a manual crawl checklist covering Success, Retreat, Defeat, terminal close, scan cancel, scan completion, reward collection, and save/resume.

## Refactor Research Backlog

Create `docs/refactor.md` during the first stabilization task. Add entries only when work exposes a concrete architectural problem.

Each entry must contain:

```markdown
## Candidate: Concise name

**Current location:** Paths and relevant symbols
**Observed while:** Stabilization task that exposed the issue
**Problem:** Concrete coupling, duplication, or responsibility problem
**Proposed boundary:** Intended responsibility and interface
**Why defer:** Why stabilization does not require the change
**Tests protecting behavior:** Tests that make the later change safer
**Likely files affected:** Expected change surface
**Risks/open questions:** Decisions required before refactoring
```

The backlog is research, not an automatic commitment. After stabilization passes, it will be reviewed and prioritized into a separate refactor design and plan.

Likely candidates already observed include:

- Extracting procedural generation from `DungeonMap`.
- Separating Alert and visibility rules from presentation.
- Separating map serialization from live scene reconstruction.
- Replacing loosely shaped terminal dictionaries and encounter arrays with typed data.
- Reducing `GameManager`'s mixture of orchestration, reward effects, and screen lifecycle management.

## Completion Criteria

Stabilization is complete when:

- All automated tests described above pass.
- Each run result is reachable and occurs exactly once.
- Terminal extraction and boss victory complete correctly.
- Save/resume round-trips authoritative map state.
- Invalid payloads cannot crash or silently consume nodes.
- Node counts and tier scaling match documented rules.
- The manual crawl checklist passes without parse or runtime errors.
- `docs/refactor.md` contains the concrete deferred findings gathered during the work.
- No Event content, new Alert mechanics, or broad architectural rewrite has entered scope.
