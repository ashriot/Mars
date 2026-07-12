# Dungeon Stabilization Verification Checklist

**Latest tested gameplay commit:** `2059db2fb7155ac71ebbb33e4aefa1fd6058a8ad`

**Initial docs-only verification commit:** `bb29480d33e6a4d4fc8538416064b0ad8912f000`

**Checklist wording amendment commit:** `7dc80b6f37c56bbc76cff8974ffe95af9388eff9`

## Automated verification completed

- [x] Full headless GUT suite run against gameplay commit `41555e2` with the vendored GUT runtime documented in `addons/gut/VENDORED.md`.
- [x] Headless editor import/parse check run against gameplay commit `41555e2`.
- [x] Repository diff whitespace check run before the docs-only verification commit.

The current automated-test baseline and canonical commands are documented in [Testing](README.md). Complete automated checks do not replace the interactive crawl below.

## Manual verification completed

Interactive verification was confirmed complete on 2026-07-11 against `2059db2`.

- [x] Start a fresh run; use the Remote Inspector or debugger to confirm `RunManager.current_dungeon_tier == 1`, then with no aware threats confirm the first move adds the base +2% Alert. Tier normalization and loot scaling are automated by `test_normalized_tier_clamps_to_minimum` and `test_loot_scalar_scales_from_normalized_tier`: 1.0 at tier 1 and 1.5 at tier 3.
- [x] Confirm the HUD actionable-node total matches the generated crawl.
- [x] Close a terminal, then reopen it and confirm it remains available.
- [x] Cancel scan targeting and confirm the same terminal reopens without being consumed.
- [x] Complete a scan and confirm the terminal is consumed exactly once.
- [x] Use Security, Medical, and Finance once each; confirm each displayed value matches its actual applied effect.
- [x] Extract from a terminal and confirm exactly one `TACTICAL RETREAT` screen.
- [x] Extract from the Entrance and confirm exactly one `TACTICAL RETREAT` screen.
- [x] Enter the Exit and confirm exactly one `MISSION COMPLETE` screen.
- [x] Win the boss encounter and confirm exactly one immediate `MISSION COMPLETE` screen without returning to the boss node.
- [x] Lose the party and confirm exactly one `CRITICAL FAILURE` screen.
- [x] Confirm the result screen twice (or attempt a double confirmation) and confirm rewards settle exactly once.
- [x] Resume a safely saved run with Alert below 75 and confirm position, node types, payloads, and visibility are preserved.
- [x] Resume a run with Alert at or above 75 and confirm no extra nodes are revealed during restore.
- [x] Corrupt `active_run.map_data.node_data`; confirm the active run is rejected while permanent inventory, heroes, and Bits are preserved.
- [x] Complete an uninterrupted crawl while watching the debugger; confirm no unexpected errors, leaks, or orphan nodes.
