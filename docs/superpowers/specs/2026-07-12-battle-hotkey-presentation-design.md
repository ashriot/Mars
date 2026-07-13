# Battle Hotkeys and World-Cursor Policy Design

## Goal

Use the polished Kenney input-prompt textures for battle hotkeys and restrict snapped cursor movement to actual UI controls. Dungeon and combat navigation use their existing reticles/highlights instead of moving the cursor through world space.

## Corrected Context

Battle input was already functional and `DynamicGlyph` was already the correct texture presentation mechanism. The first implementation on this branch incorrectly replaced keyboard textures with plain text labels, producing the small `1` and `2` seen over the battle controls.

The curated keyboard asset directory no longer contains number or Shift sources, although Godot's import cache proves those Kenney assets were previously imported. The official Kenney Input Prompts 1.5 pack contains the required keyboard SVGs and is CC0 licensed.

Map and battle adapters also explicitly assign `NavigationCursor` targets to map nodes and actor cards. That causes the pointer to fly between world objects even though both systems already have dedicated selection feedback.

## Hotkey Presentation

Restore exactly these five source SVGs from the official Kenney Input Prompts 1.5 archive:

- `keyboard_1.svg`
- `keyboard_2.svg`
- `keyboard_3.svg`
- `keyboard_4.svg`
- `keyboard_shift.svg`

Place them in `assets/graphics/glyphs/keyboard_mouse/vector/`. Do not restore the full 1,500-file pack or commit generated `.import` sidecars.

`InputIconMap.GLYPH_FILES[KEYBOARD_MOUSE]` maps:

- `action_1` → `keyboard_1.svg`;
- `action_2` → `keyboard_2.svg`;
- `action_3` → `keyboard_3.svg`;
- `action_4` → `keyboard_4.svg`;
- `shift_action` → `keyboard_shift.svg`.

Keyboard confirm/cancel textures remain unchanged. Every controller-family face-button and trigger mapping remains unchanged.

`DynamicGlyph` remains texture-only. In controller mode it resolves the active controller family; in keyboard/mouse mode it resolves `ControllerType.KEYBOARD_MOUSE`. Unknown actions clear textures and hide safely. The temporary `KEYBOARD_LABELS`, `get_keyboard_label()`, and child `Label` implementation are removed.

Disabled or unavailable controls retain the existing texture and inherit the current 0.33 opacity. Mode and controller-family changes refresh immediately without changing the authored layout.

## Cursor Ownership Policy

### UI Screens

The cursor may snap to interactive `Control` nodes on:

- title screen;
- hub and nested hub panels;
- terminal modals;
- result screens;
- other true menu/modal UI governed by `NavigationUXLayer`.

Existing modal ownership, focus restoration, and UI cursor synchronization remain unchanged.

### Dungeon Map

Dungeon navigation continues to use:

- the player marker for current position;
- the reticle for preview and scan selection;
- node state and highlights for eligibility.

Selecting, cancelling, confirming, restoring the map after a terminal, or restoring a preview never assigns a world target to `NavigationCursor`. The live map adapter clears the cursor target instead.

### Combat

Combat navigation continues to use:

- actor hover/highlight presentation;
- action-button textures;
- targeting validity states.

Changing, restoring, cancelling, or confirming a controller target never assigns an actor card to `NavigationCursor`. The live battle adapter clears the cursor target instead. The logical `_controller_target` remains unchanged and continues driving selection and execution.

### Visibility and Input Mode

When the map or battle owns navigation:

- keyboard/controller navigation has no valid cursor target, so snapped behavior hides the cursor;
- meaningful mouse motion switches to free behavior, and the cursor immediately reappears at the real mouse position;
- subsequent keyboard/controller navigation switches back to snapped behavior and hides it again;
- world selection state is never inferred from cursor position.

This behavior uses the existing `NavigationCursor.clear_target()` plus `InputManager` free/snapped transitions. It does not add timers, idle detection, or a second cursor system.

## Architecture and Boundaries

- `InputIconMap` owns all texture paths.
- `DynamicGlyph` displays textures only.
- `DungeonMap` owns map reticle/preview state and always clears global cursor targeting.
- `BattleScene` owns logical actor selection/highlighting and always clears global cursor targeting.
- `NavigationUXLayer` continues snapping to real UI controls and restoring modal/UI focus.
- `NavigationCursor` and `InputManager` require no new public API.

No battle bindings, targeting rules, map movement, combat execution, click handling, or controller mappings change.

## Testing

Automated coverage must verify:

- all five restored Kenney SVGs exist and are the only newly restored keyboard source assets;
- keyboard action/shift mappings resolve those exact resource paths;
- every controller family still resolves all four actions plus `shift_action`;
- `DynamicGlyph` shows a keyboard texture in keyboard/mouse mode and the correct family texture in controller mode;
- no child keyboard label exists or remains visible;
- unknown actions hide safely;
- disabled action glyphs remain visible and dimmed;
- real action buttons and both real shift controls switch between exact keyboard and controller textures;
- map preview, cancel, terminal close/restore, and adapter restoration leave the global cursor without a world target while retaining reticle/current/preview state;
- battle target changes, cancel, modal close/restore, and adapter restoration leave the global cursor without an actor target while retaining logical target/highlight behavior;
- meaningful mouse motion in map and battle makes the free cursor visible again, and a subsequent navigation event hides it without changing world selection;
- title, hub, terminal, and result UI cursor tests remain green.

## Verification

Completion requires:

1. focused glyph, map, battle, and navigation tests pass under Godot 4.6.3/GUT 9.6.1;
2. the complete suite passes with zero failures;
3. headless editor import exits successfully;
4. `git diff --check` passes;
5. only the five Kenney SVGs, input/glyph code, map/battle cursor ownership, tests, and revised documentation are committed.

The staged 1,000-XP hero resources and unstaged GUT theme normalization remain untouched and outside feature commits.

## Out of Scope

- Changing battle or map controls.
- Removing mouse clicking from map or combat.
- Hiding the mouse pointer while it is actively being used.
- Changing UI cursor snapping on title, hub, terminal, or result screens.
- Restoring the complete Kenney asset pack.
- Adding idle timers or cursor fade animations.
