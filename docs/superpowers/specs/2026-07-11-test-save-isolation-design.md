# Test Save Isolation Design

## Goal

Automated tests must never read, overwrite, or delete a player's real save-slot files, even when a test calls production save/load methods or a developer runs GUT without a temporary `HOME`.

## Design

`SaveSystem` will detect the GUT command-line runner and resolve `user://saves/` operations into a separate test-only directory. Production runs will continue resolving the existing `user://saves/slot_<n>.json` paths without change.

This boundary belongs in `SaveSystem._get_slot_path()` so every current caller—including `save_game()`, `load_game()`, `has_save()`, and test cleanup—receives the isolated path automatically. Tests must not be able to opt out accidentally by choosing slot 1.

Individual test suites will continue to use dedicated high-numbered slots and restore or remove their files during teardown. Test commands will continue setting a temporary `HOME`. These are secondary containment layers, not the primary guarantee.

## Detection and Paths

The test-process check will inspect Godot's command-line arguments for the GUT runner script (`addons/gut/gut_cmdln.gd`). In that process:

- Production: `user://saves/slot_1.json`
- GUT: `user://test_saves/slot_1.json`

The test directory will be created on demand before writes. Normal game and editor launches will not use or migrate test saves.

## Failure Behavior

If the test directory cannot be created or a file cannot be opened, existing Godot file-access behavior remains visible to the caller. The isolation mechanism must never fall back to the production save directory.

## Verification

Tests will verify that:

1. GUT resolves a slot path beneath `user://test_saves/`.
2. The resolved path is different from the production `user://saves/` path.
3. A production save call exercised by the restore-routing test writes only to its isolated test slot.
4. The full suite passes using a temporary `HOME`.
5. The real slot-1 checksum is unchanged across a test run performed without a temporary `HOME`.

## Scope

This change protects save files during automated GUT runs. Recovering the already overwritten prototype slot is separate and intentionally excluded. No gameplay save format or progression behavior changes.
