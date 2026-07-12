# Battle Hotkey Presentation Design

## Goal

Make battle ability controls discoverable in both input modes. Ability and shift controls show their actual keyboard hotkey in keyboard/mouse mode and the correct device-family glyph in controller mode.

## Current Behavior

Battle input is already functional:

- `action_1` through `action_4` select the four ability slots;
- `shift_action` activates the available shift;
- targeting uses semantic navigation, confirm, and cancel.

The presentation is incomplete. `DynamicGlyph` clears and hides itself whenever the active mode is keyboard/mouse. Controller input therefore reveals face-button/trigger glyphs, while keyboard and mouse users see no indication that abilities are bound to `1`, `2`, `3`, and `4`.

The existing keyboard entry in `InputIconMap.GLYPH_FILES` is also stale for combat actions: it maps them to Space/A/S/D assets rather than the live 1–4 bindings. The deliberately filtered keyboard asset set does not contain number-key or Shift-key icons.

## Presentation Contract

### Keyboard and Mouse

- Ability slot 1 shows `1`.
- Ability slot 2 shows `2`.
- Ability slot 3 shows `3`.
- Ability slot 4 shows `4`.
- Both left and right shift controls show `SHIFT` because they share `shift_action` and only the currently legal direction is enabled/visible.
- Labels remain visible on disabled or unaffordable controls but inherit the existing 0.33 disabled opacity.
- Mouse click behavior is unchanged.

### Controller

- Ability slots continue to show the existing controller-family face-button textures.
- Shift controls continue to show the existing controller-family trigger textures.
- Xbox, PlayStation, Nintendo Switch, Nintendo Switch 2, Steam Controller, and Steam Deck mappings remain unchanged.
- Switching controller family refreshes the visible texture immediately.

### Mode Switching

- Meaningful keyboard or mouse input replaces the controller texture with the keyboard label immediately.
- Meaningful controller input hides the keyboard label and restores the current controller texture immediately.
- The control occupies the same authored footprint in both modes, so the action bar does not reflow or move.
- Unknown/unmapped actions clear both presentations and hide safely.

## Architecture

`InputIconMap` owns semantic input presentation data. Add an immutable keyboard label map for only the battle actions:

```gdscript
const KEYBOARD_LABELS := {
	&"action_1": "1",
	&"action_2": "2",
	&"action_3": "3",
	&"action_4": "4",
	&"shift_action": "SHIFT",
}
```

Expose `get_keyboard_label(action: StringName) -> String`. This avoids parsing `InputMap` event text at runtime and makes the displayed contract explicit and testable. The obsolete keyboard combat entries in `GLYPH_FILES` are removed; keyboard confirm/cancel mappings may remain for other presentation consumers.

`DynamicGlyph` remains the single battle presentation control. It keeps its existing controller texture behavior and owns one centered child `Label` for keyboard text. The label is created or resolved once, ignores mouse input, fills the existing control bounds, and uses a compact font size that fits `SHIFT`. `DynamicGlyph.refresh()` chooses exactly one representation:

- controller mode: keyboard label hidden, controller texture shown;
- keyboard/mouse mode: textures cleared, mapped keyboard label shown;
- unmapped action: both cleared and the control hidden.

No new bitmap or SVG assets are added. No action-button layout or input-handling code changes.

## Testing

Unit coverage must verify:

- exact keyboard labels for `action_1` through `action_4` and `shift_action`;
- unmapped actions return an empty label;
- keyboard/mouse mode shows text and no controller texture;
- controller mode shows texture and hides text;
- mode changes refresh immediately in both directions;
- controller family changes still replace the texture;
- unmapped actions hide safely;
- disabled ActionButton presentation dims the visible keyboard label/control exactly as it dims controller glyphs.

Integration coverage must instantiate the real action bar or action buttons and confirm slots 1–4 display `1–4` in keyboard/mouse mode, then switch to controller mode and confirm all four use textures with no residual text. Both real shift controls must show `SHIFT` in keyboard/mouse mode and the family trigger in controller mode.

The complete battle-controller and playable-loop tests remain green to prove presentation changes do not alter input execution.

## Verification

Completion requires:

1. focused `test_dynamic_glyph.gd` passes;
2. focused battle controller integration tests pass;
3. full GUT suite passes with zero failing tests;
4. headless editor import exits successfully;
5. `git diff --check` passes;
6. only `InputIconMap`, `DynamicGlyph`, their tests, and this feature's documentation are committed.

The staged 1,000-XP hero-resource changes and unstaged GUT theme normalization are unrelated and must remain untouched.

## Out of Scope

- Changing battle bindings or execution behavior.
- Adding focus navigation across ability buttons.
- Reintroducing filtered keyboard number/Shift image assets.
- Showing general non-clickable action hints in keyboard/mouse mode.
- Changing the cursor during combat.
