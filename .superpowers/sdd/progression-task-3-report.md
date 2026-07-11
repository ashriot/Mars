# Progression Redesign Task 3 Report

## Status

DONE

## Implementation

- Added `HeroRoleProgress` with strict new-format serialization for content revision, owned node IDs, and the exact XP paid per node.
- Extended `HeroData` with typed per-role progression state. Legacy `unlocked_node_ids` remains independent and is never translated into the new records.
- Loading rejects malformed role records, returns affected role IDs, and reports expected-revision mismatches while preserving the loaded historical record without reset or refund.
- Added typed `ProgressionPurchaseResult` and all required statuses/payload fields.
- Added `ProgressionService` with an injected catalog and Task-4 rebuild callable. All validation occurs before the single commit section; success deducts once, records ownership/price/revision once, then calls rebuild.
- Added duplicate-call, rejection immutability, historical-price/revision, malformed save, mismatch, prototype cutover, and save round-trip coverage.

## TDD Evidence

- RED: focused unit test failed to parse because `HeroRoleProgress`, `ProgressionPurchaseResult`, and `ProgressionService` did not exist and `HeroData.load_from_save_data` lacked the new interface.
- GREEN: `test_progression_service.gd`: 3/3 tests, 52 assertions.
- Focused integration: `test_hub_progression.gd`: 7/7 tests, 50 assertions.
- Full GUT suite: 15 scripts, 114/114 tests, 771 assertions.

All verification used the preserved isolated HOME at `/private/tmp/mars-task3-home`. Godot emitted only the environment's macOS CA-certificate warning; expected-error tests were recognized by GUT.

## Concerns / Follow-up

- The rebuild callable is intentionally temporary and should be replaced by Task 4's derived-state rebuild interface.
- Existing prototype UI still consumes `unlocked_node_ids`; this task does not migrate or translate that state by design.
