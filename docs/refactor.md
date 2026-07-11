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

## Candidate: Extract procedural map generation

**Current location:** `src/map/dungeon_map.gd`, especially `_distribute_node_types()` and `generate_hex_grid()`

**Observed while:** Reviewing node-count and restore defects

**Problem:** Random layout generation, live scene creation, HUD progress, and serialized run state share one script.

**Proposed boundary:** A `DungeonGenerator` that accepts dimensions, profile multipliers, endpoint rules, and a seed, then returns plain map data.

**Why defer:** Pure count helpers are enough to stabilize current generation without moving scene construction.

**Tests protecting behavior:** Seed determinism, node-count invariants, and payload/type correspondence.

**Likely files affected:** `src/map/dungeon_map.gd`, a future generator script, and dungeon generation tests.

**Risks/open questions:** Decide whether generated map data should be a typed `Resource` or immutable dictionaries.

## Candidate: Separate run presentation from run lifecycle

**Current location:** `src/battle/game_manager.gd`, `src/map/dungeon_end_screen.gd`, and `src/singletons/run_manager.gd`

**Observed while:** Reviewing duplicate cleanup and reward-commit paths

**Problem:** Screen lifecycle, map locking, outcome selection, and reward commitment are coordinated through callbacks across three scripts.

**Proposed boundary:** A non-autoload run lifecycle object with explicit `begin_end(result)` and `confirm_end()` transitions.

**Why defer:** A guarded `GameManager` transition fixes correctness with a smaller change.

**Tests protecting behavior:** One-shot Success, Retreat, Defeat, and reward commitment tests.

**Likely files affected:** The three current scripts plus a future lifecycle script.

**Risks/open questions:** Decide whether confirmation belongs to the controller or remains a screen signal.
