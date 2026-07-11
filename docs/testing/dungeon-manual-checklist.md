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

- [ ] Start a fresh run and confirm dungeon tier 1 and its scalar-derived encounter/loot behavior.
- [ ] Confirm the HUD actionable-node total matches the generated crawl.
- [ ] Close a terminal, then reopen it and confirm it remains available.
- [ ] Cancel scan targeting and confirm the same terminal reopens without being consumed.
- [ ] Complete a scan and confirm the terminal is consumed exactly once.
- [ ] Confirm Security, Medical, and Finance displayed choices match their applied effects.
- [ ] Extract from a terminal and confirm Retreat produces exactly one result screen.
- [ ] Extract from the Entrance and confirm Retreat.
- [ ] Enter the Exit and confirm Success.
- [ ] Win the boss encounter and confirm immediate Success without returning to the boss node.
- [ ] Lose the party and confirm Defeat.
- [ ] Confirm the result screen twice (or attempt a double confirmation) and confirm rewards settle exactly once.
- [ ] Resume a safely saved run with Alert below 75 and confirm state is preserved.
- [ ] Resume a run with Alert at or above 75 and confirm no extra nodes are revealed during restore.
- [ ] Load a corrupted `active_run` and confirm it is rejected while permanent progression is preserved.
- [ ] Complete an uninterrupted crawl while watching the debugger; confirm no unexpected errors, leaks, or orphan nodes.
