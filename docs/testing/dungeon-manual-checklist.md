# Dungeon Stabilization Verification Checklist

**Tested gameplay commit:** `41555e2`

**Docs-only verification commit:** Record after committing this checklist and the related verification documentation.

## Automated verification completed

- [x] Full headless GUT suite run against gameplay commit `41555e2` with the vendored GUT runtime documented in `addons/gut/VENDORED.md`.
- [x] Headless editor import/parse check run against gameplay commit `41555e2`.
- [x] Repository diff whitespace check run before the docs-only verification commit.

Automated results and the docs-only verification commit are reported in the Task 8 handoff. These checks do not replace the interactive crawl below.

## Manual verification pending

Do not mark an item complete without interactively playing the scenario and recording any observed error or mismatch.

- [ ] Start a fresh run at dungeon tier 1; confirm the first movement cost and loot scalar use tier 1 values rather than tier 0 values.
- [ ] Confirm the HUD actionable-node total matches the generated crawl.
- [ ] Close a terminal, then reopen it and confirm it remains available.
- [ ] Cancel scan targeting and confirm the same terminal reopens without being consumed.
- [ ] Complete a scan and confirm the terminal is consumed exactly once.
- [ ] Use Security, Medical, and Finance once each; confirm each displayed value matches its actual applied effect.
- [ ] Extract from a terminal and confirm exactly one `TACTICAL RETREAT` screen.
- [ ] Extract from the Entrance and confirm exactly one `TACTICAL RETREAT` screen.
- [ ] Enter the Exit and confirm exactly one `MISSION COMPLETE` screen.
- [ ] Win the boss encounter and confirm exactly one immediate `MISSION COMPLETE` screen without returning to the boss node.
- [ ] Lose the party and confirm exactly one `CRITICAL FAILURE` screen.
- [ ] Confirm the result screen twice (or attempt a double confirmation) and confirm rewards settle exactly once.
- [ ] Resume a safely saved run with Alert below 75 and confirm position, node types, payloads, and visibility are preserved.
- [ ] Resume a run with Alert at or above 75 and confirm no extra nodes are revealed during restore.
- [ ] Corrupt `active_run.map_data.node_data`; confirm the active run is rejected while permanent inventory, heroes, and Bits are preserved.
- [ ] Complete an uninterrupted crawl while watching the debugger; confirm no unexpected errors, leaks, or orphan nodes.
