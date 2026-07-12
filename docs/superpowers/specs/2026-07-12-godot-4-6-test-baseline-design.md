# Godot 4.6.3 Test Baseline Design

## Goal

Make Godot 4.6.3 the single supported development, automated-test, and iOS prototype baseline. Replace the currently mismatched Godot 4.7 test harness so the repository can produce a trustworthy full-suite result using the same engine version as the game.

## Context

The project metadata already targets Godot 4.6, and Godot 4.6.3 has been verified on an iPhone. Godot 4.7 currently has unacceptable iOS visual issues, so it is not a supported runtime.

The automated tests are mismatched with that decision. `addons/gut` was vendored from GUT's `godot_4_7` branch at runtime version 9.7.1, `test_test_harness.gd` requires Godot 4.7, and active testing documentation instructs developers to use 4.7. Under Godot 4.6.3, that harness references APIs and type behavior introduced for 4.7, including `AccessibilityServer` and a typed `StringName` default that cannot be `null`.

## Dependency Baseline

- Godot is pinned to official version 4.6.3 for development and automated tests.
- GUT is pinned to official tag `v9.6.1`, commit `c80954f47bed74a0a2c471d472c0389f98e0a8f6`.
- The complete vendored `addons/gut` directory is replaced from that upstream revision instead of selectively mixing 9.6 and 9.7 files.
- `addons/gut/VENDORED.md` records the tag, exact commit, source URL, runtime version, and any repository-only normalization.
- No local compatibility patches are added unless the unmodified 9.6.1 release demonstrably cannot run this project under Godot 4.6.3.

This full replacement creates a reproducible dependency boundary and avoids maintaining a private hybrid GUT version.

## Harness Contract

`test/unit/test_test_harness.gd` verifies the exact supported engine line:

- major version equals `4`;
- minor version equals `6`;
- patch version equals `3`.

The canonical headless command uses the installed Godot 4.6.3 binary and vendored GUT 9.6.1. It must discover and execute the suite without the current GUT parser errors or debugger crash. Existing macOS certificate and engine shutdown diagnostics may be documented separately when they do not affect test discovery or results; test failures may not be ignored.

## Game-Code Compatibility

Replacing the harness and correcting the engine assertion come first. The full suite is then run without changing game code preemptively.

If the `RoleTreeDefinition` typed-array failure remains under the correct harness, it is treated as a real Godot 4.6.3 compatibility defect. A regression test must fail for the observed reason before production code changes. The fix must preserve the existing public contract:

- invalid trees remain fail-closed;
- `starting_node_ids`, `nodes`, and `get_children()` return empty typed arrays for invalid trees;
- valid-tree defensive-copy and ordering behavior remains intact.

No progression redesign or unrelated refactor is included.

## Documentation

Update active sources of truth that tell developers how to run or interpret tests:

- `addons/gut/VENDORED.md`;
- the current manual testing checklist or testing README where it states 4.7 is required;
- the harness version assertion.

Historical design specifications and implementation plans remain historical records and are not rewritten merely because they mention the environment used at that time. A concise current testing document should supersede them for present-day instructions if no such source already exists.

The documentation records that Godot 4.6.3 is intentionally pinned because it has been verified on iPhone, while Godot 4.7 is deferred due to iOS visual issues.

## Verification

Completion requires fresh evidence from Godot 4.6.3:

1. Import/editor startup exits successfully.
2. The harness-version test passes and reports Godot 4.6.3 with GUT 9.6.1.
3. The focused progression-definition tests pass.
4. The canonical full suite completes with zero failing tests.
5. GUT no longer emits the `AccessibilityServer` or `stub_params.gd` compatibility parser errors.
6. `git diff --check` passes.
7. Only intended dependency, harness, compatibility, and current documentation files are committed; unrelated edits to `project.godot` and `data/heroes/asher/actions/aimed_shot.tres` remain unstaged.

## Out of Scope

- Moving back to Godot 4.7.
- Solving Godot 4.7 iOS rendering issues.
- Changing gameplay, UI, progression balance, or save formats.
- Modernizing or refactoring GUT.
- Rewriting historical planning documents.
