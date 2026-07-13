# Directional Combat Shift Controls

## Goal

Make each combat role-shift card use a deterministic input that matches its screen position. The left card uses the left trigger or Q; the right card uses the right trigger or E. The glyph shown on each card must describe the input that activates that card.

## Input Contract

- Add separate semantic actions named `shift_left` and `shift_right`.
- Bind `shift_left` to keyboard Q and the controller's left trigger.
- Bind `shift_right` to keyboard E and the controller's right trigger.
- L2/Q activates only the visible, enabled left role card.
- R2/E activates only the visible, enabled right role card.
- A hidden or disabled side ignores its directional action. It never falls back to the opposite card.
- When the same unlocked role is intentionally rendered on both sides, either side may shift into it through its own directional action.
- Existing mouse activation remains unchanged.

## Presentation

The left and right `DynamicGlyph` controls reference `shift_left` and `shift_right`, respectively. `InputIconMap` resolves those actions to the matching Kenney keyboard Q/E glyphs and the matching L2/R2 glyph for every supported controller family. Combat continues to suppress the redundant global action-hint panel.

## Implementation Boundary

`ActionBar` owns the two directional actions because it already owns the role cards, their availability, and their mouse activation. The global input map and `InputIconMap` define bindings and presentation; no raw key or physical controller checks are added to combat code.

The existing shared `shift_action` is removed from combat shift-card handling once no runtime or test consumer needs it. Other navigation actions that happen to use Q/E or L2/R2 remain valid because they are handled in different screen contexts.

## Verification

Automated coverage will verify:

- the two semantic actions exist with Q/E and left/right trigger bindings;
- each controller family and keyboard mode resolves the correct directional glyph;
- each action activates only its matching visible, enabled card;
- duplicate left/right cards may both reach the same role without fallback logic;
- mouse activation and existing combat action controls remain unchanged.

Manual controller acceptance will confirm that the displayed L2/R2 glyphs match the physical DualSense triggers and that Q/E match the left/right card layout in keyboard-and-mouse mode.
