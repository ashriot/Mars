# Keyboard Navigation Parity Design

## Goal

Make arrow keys and WASD behave identically on standard UI screens while preserving their intentionally different dungeon-map responsibilities: WASD selects map nodes and arrow keys pan the camera.

## Current Failure

The project has two independent keyboard navigation paths:

- Godot `Control` focus responds to built-in `ui_up`, `ui_down`, `ui_left`, and `ui_right`. Arrow keys therefore change the focused button, but `InputManager` does not classify those actions as snapped navigation, so the custom cursor does not follow.
- WASD is bound to custom `nav_up`, `nav_down`, `nav_left`, and `nav_right`. `InputManager` switches the cursor to snapped mode, but ordinary Godot buttons do not consume those custom actions, so focus does not move.

The dungeon camera has a separate binding defect. `camera_pan_up` and `camera_pan_down` use the correct Godot 4.6.3 key codes, while `camera_pan_left` and `camera_pan_right` use unrelated raw numeric values instead of `KEY_LEFT` and `KEY_RIGHT`. This allows vertical arrow panning but breaks horizontal panning.

## Input Responsibilities

### Standard UI

Both WASD and arrow keys drive built-in `ui_*` directional actions. Either family must:

1. move Godot focus exactly once;
2. keep the input family as keyboard/mouse;
3. select snapped cursor behavior;
4. move and physically synchronize the custom cursor to the newly focused control.

### Semantic Navigation

Custom `nav_*` actions retain WASD and controller bindings for gameplay navigation, including skill-tree geometry, dungeon-node selection, and battle targeting. Arrow keys are not added to `nav_*`.

This separation prevents one arrow press on the dungeon map from both panning the camera and changing the selected node.

### Dungeon Camera

The four `camera_pan_*` actions use the corresponding Godot 4.6.3 physical arrow-key constants:

- `camera_pan_left` → `KEY_LEFT` (`4194319`);
- `camera_pan_right` → `KEY_RIGHT` (`4194321`);
- `camera_pan_up` → `KEY_UP` (`4194320`);
- `camera_pan_down` → `KEY_DOWN` (`4194322`).

Existing right-stick camera bindings remain unchanged.

## Implementation Boundary

`project.godot` is the source of action bindings:

- add physical W, A, S, and D events to the matching built-in `ui_*` actions without removing their existing arrow/controller defaults;
- leave the four custom `nav_*` keyboard bindings as WASD-only;
- replace only the incorrect horizontal `camera_pan_*` key events with the verified constants.

`InputManager` expands its snapped-navigation classification to include `ui_left`, `ui_right`, `ui_up`, and `ui_down`. It does not translate, synthesize, or re-dispatch input events.

No screen-specific navigation code is added. Godot remains responsible for ordinary UI focus, while existing semantic adapters remain responsible for gameplay navigation.

## Testing

Automated tests must cover:

- `InputManager` classifies each WASD `nav_*` input and each arrow `ui_*` input as keyboard/mouse with snapped cursor behavior.
- The Input Map contains the matching WASD event for each built-in `ui_*` direction.
- The Input Map keeps arrow keys out of custom `nav_*` actions.
- The four dungeon camera actions contain the exact corresponding arrow-key event.
- A hub integration test sends Arrow Right and D from the same starting button in separate fixture resets and observes the same next focus and cursor destination.
- A dungeon integration test confirms the four arrow actions produce the expected camera direction and that arrow events do not become `nav_*` selection events.
- Existing controller, skill-tree, battle, modal, and cursor-continuity tests remain green.

Tests must observe one destination change per event so duplicated action handling cannot pass unnoticed.

## Verification

Completion requires:

1. focused InputManager and hub navigation tests pass under Godot 4.6.3/GUT 9.6.1;
2. focused dungeon navigation tests pass;
3. the full suite passes with zero failing tests;
4. headless editor import exits successfully;
5. `git diff --check` passes;
6. only input configuration, InputManager, relevant tests, and this feature's documentation are committed.

All unrelated working-tree edits present at execution time are user/editor-owned and must remain unstaged. Any pre-existing `project.godot` content must be preserved while making the scoped input changes.

## Out of Scope

- Changing controller mappings.
- Changing mouse/free-cursor behavior.
- Reassigning WASD to dungeon camera panning.
- Adding arrow keys to dungeon-node selection or battle targeting.
- Refactoring screen-specific focus systems.
- Adding the temporary 1,000 XP testing default; that remains a separate follow-up.
