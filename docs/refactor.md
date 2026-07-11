# Refactor Research Backlog

This file records architectural evidence discovered during stabilization. Items here are not part of the stabilization scope. Each candidate must cite tests that preserve its behavior before it is scheduled.

Use this template for future candidates:

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

## Candidate: Separate save serialization from map geometry

**Current location:** `src/map/dungeon_save_codec.gd`, especially `_expected_coordinate_keys()` and `extract_node_types()`, and `src/map/dungeon_map.gd` grid construction and save/restore methods

**Observed while:** Stabilizing authoritative map restore and rejecting malformed active-run data

**Problem:** The save codec duplicates the live map's hex-coordinate geometry to validate an exact coordinate set, so serialization validation can drift from the code that constructs the map it validates.

**Proposed boundary:** Give one map-geometry component ownership of valid coordinate enumeration, and keep the codec responsible only for serialized shape/type validation and conversion across the persistence boundary.

**Why defer:** The duplicated calculation is currently covered and changing geometry ownership is not required to make restore deterministic or malformed saves safe.

**Tests protecting behavior:** `test/unit/test_dungeon_save_codec.gd` protects coordinate completeness, coordinate conversion, node enums, and malformed memories; `test/integration/test_dungeon_restore.gd` protects authoritative node restoration and round-trip serialization.

**Likely files affected:** `src/map/dungeon_save_codec.gd`, `src/map/dungeon_map.gd`, a future map-geometry helper, and the codec/restore tests.

**Risks/open questions:** The geometry API must preserve odd-row offsets and exact serialized coordinate keys; decide whether dimensions alone fully define valid coordinates for every future map shape.

## Candidate: Replace loosely shaped interaction payloads with typed resources

**Current location:** `src/map/dungeon_save_codec.gd` payload validators, `src/map/dungeon_map.gd` terminal/encounter/reward memories, and `src/battle/game_manager.gd` interaction handlers

**Observed while:** Adding defensive validation for missing and malformed terminal, encounter, and reward payloads

**Problem:** Terminal dictionaries, encounter arrays, and reward dictionaries encode required fields by convention, forcing the codec and every runtime consumer to repeat shape checks and string/index access.

**Proposed boundary:** Introduce typed terminal, encounter, and reward payload resources with explicit serialization constructors that return a validated object or a contextual failure.

**Why defer:** Runtime validation already prevents crashes and accidental node consumption; changing persisted and generated payload representations would be a cross-cutting migration outside stabilization.

**Tests protecting behavior:** `test/unit/test_dungeon_save_codec.gd` covers every accepted payload category and malformed variants; `test/integration/test_game_manager_interactions.gd` covers retry-safe errors and valid interaction dispatch; `test/unit/test_terminal.gd` protects terminal option presentation.

**Likely files affected:** `src/map/dungeon_save_codec.gd`, `src/map/dungeon_map.gd`, `src/battle/game_manager.gd`, `src/map/terminal.gd`, loot generation code, and new payload resource scripts.

**Risks/open questions:** Define stable serialized forms, resource identity/duplication rules, and compatibility policy before replacing dictionaries and arrays.

## Candidate: Separate GameManager orchestration from run lifecycle and presentation

**Current location:** `src/battle/game_manager.gd`, `src/map/dungeon_end_screen.gd`, and `src/singletons/run_manager.gd`

**Observed while:** Stabilizing one-shot Success, Retreat, Defeat, terminal extraction, boss victory, and result confirmation

**Problem:** `GameManager` dispatches every node interaction and battle while also owning the run-end guard, transient-overlay cleanup, result-screen creation, confirmation handling, and exit emission across callbacks shared with `DungeonEndScreen` and `RunManager`.

**Proposed boundary:** Keep interaction orchestration in `GameManager`, but move guarded `begin_end(result)` and `confirm_end()` transitions plus result presentation ownership into a non-autoload run lifecycle controller.

**Why defer:** The guarded transitions now make current behavior idempotent; moving scene ownership and signals would broaden the stabilization change without correcting another observed defect.

**Tests protecting behavior:** `test/integration/test_game_manager_interactions.gd` protects one-shot Success, Retreat, Defeat, overlay cleanup, and exit emission; `test/unit/test_run_rewards.gd` protects result-specific and idempotent reward settlement.

**Likely files affected:** `src/battle/game_manager.gd`, `src/map/dungeon_end_screen.gd`, `src/singletons/run_manager.gd`, their interaction/reward tests, and a future lifecycle controller.

**Risks/open questions:** Decide whether the controller instantiates presentation or receives it, who owns the exit signal, and how asynchronous overlay cleanup is canceled during scene teardown.

## Candidate: Expand component loot content and balancing

**Current location:** `data/materials/`, `src/singletons/item_database.gd`, and `src/singletons/loot_manager.gd`

**Observed while:** Replacing synthesized component reward IDs with registered-resource selection

**Problem:** Registered component content is currently limited to weapon tier 1, so unsupported tiers and missing rarity matches fall back to sparse existing content rather than representing the requested armor, tier, and rarity combinations.

**Proposed boundary:** Define the intended armor/tier component catalog and explicit selection/fallback policy, then balance the current 25% rare request branch against that content.

**Why defer:** Stabilization requires every generated reward to resolve and validate; content expansion and probability changes require separate game-design decisions.

**Tests protecting behavior:** `test/unit/test_loot_manager.gd` protects registered-resource selection, fallback validity, stale-entry rejection, and the current rarity threshold.

**Likely files affected:** Component resources under `data/materials/`, `src/singletons/item_database.gd`, `src/singletons/loot_manager.gd`, and loot tests.

**Risks/open questions:** Decide armor and tier coverage, whether fallback should preserve rarity or tier first, how absent combinations surface to players, and whether the 25% rare request probability remains appropriate after the catalog expands.
