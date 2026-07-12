# Cursor Snap Continuity Design

## Purpose

Keep the visual navigation cursor and the physical mouse position synchronized when keyboard or controller navigation snaps focus to a UI element. Moving the mouse afterward must continue from the snapped location rather than jumping back to stale pre-navigation coordinates.

## Input and Cursor State

Input family and cursor movement style remain separate concepts:

- Input family remains `KEYBOARD_MOUSE` or `CONTROLLER` and continues to control glyph visibility.
- Cursor movement style is either free mouse movement or focus-snapped navigation.
- Keyboard navigation does not display controller glyphs.

## Snap Behavior

When keyboard navigation or controller navigation moves focus to a UI control:

- The custom cursor snaps/tweens to the focused control's cursor anchor.
- The hidden physical mouse position is warped to the same viewport coordinate.
- The warp happens whenever the snapped focus target changes, including page, role, modal, and screen restoration.
- Re-targeting the same coordinate does not repeatedly warp the mouse.
- The cursor never warps to an invalid, hidden, disabled, freed, or off-tree target.

Keyboard navigation includes semantic UI navigation actions such as directional movement, confirm/cancel focus transitions, page changes, role changes, and modal/screen focus restoration. Ordinary typing that does not move UI focus does not initiate a snap.

## Mouse Handoff

`Input.warp_mouse()` may generate a synthetic `InputEventMouseMotion`. That event must not be interpreted as genuine user mouse input.

- Record the expected warp position before calling `Input.warp_mouse()`.
- Ignore the corresponding mouse-motion event within a small positional tolerance.
- Clear the pending-warp marker after consuming the synthetic event or after a short bounded frame window so real input cannot be suppressed indefinitely.
- The first meaningful real mouse movement switches cursor movement back to free mode.
- Free movement begins at the synchronized snapped coordinate and follows the physical mouse normally.

## Controller Handoff

Controller focus navigation uses the same physical-mouse synchronization. When the player later moves the mouse, the cursor continues from the last controller-snapped target instead of returning to an older mouse location.

Controller glyphs remain visible until genuine mouse or keyboard input changes the input family. Ignoring a synthetic warp event must not change controller mode or hide controller hints.

## Ownership

- `InputManager` classifies input family and distinguishes genuine mouse motion from a pending programmatic warp.
- `NavigationCursor` owns cursor target positioning and requests physical mouse synchronization when it snaps.
- `NavigationUXLayer` continues to own focus targets; it does not duplicate mouse-warp logic.

## Testing

Automated tests verify:

- Keyboard navigation focus causes the cursor and injected physical-mouse seam to receive the focused control coordinate.
- Controller navigation does the same.
- The synthetic motion corresponding to a warp is ignored and does not switch controller mode.
- A later genuine mouse motion switches to keyboard/mouse mode and moves freely from the snapped coordinate.
- Repeated processing of an unchanged target does not repeatedly warp.
- Invalid targets clear safely without warping.
- Page/role changes and modal restoration synchronize to the restored focus target.

Focused input-manager, navigation-cursor, navigation-UX, hub navigation, and full GUT tests must pass. The unrelated local `project.godot` modification remains outside this work.
