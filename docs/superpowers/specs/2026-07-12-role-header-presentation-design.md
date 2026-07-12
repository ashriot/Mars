# Role Header Presentation Design

## Purpose

Simplify the role anchor and remove the sticky mouse-click highlight from progression nodes without changing progression ownership, purchasing, or controller navigation.

## Role Anchor

- Remove the role-description label from the anchor scene and script.
- Keep the role icon, uppercase role name, and left/right/down connection arrows.
- Vertically center the icon and role name within the existing `250 × 50` anchor.
- Keep the anchor focusable for mouse/controller navigation and non-purchasable.

## Skill Node Interaction

- Progression-node buttons are momentary controls, not toggles.
- Clicking or tapping a node must never leave `button_pressed` enabled after activation.
- Clicking an available paid node continues to emit the existing purchase request exactly once.
- Clicking an owned starting skill continues to inspect/focus it without requesting a purchase.
- Mouse focus continues to synchronize the stable node ID so switching to a controller remains seamless.

## Persistent and Transient Presentation

- Persistent node presentation comes only from progression state: locked, available, affordable, or owned.
- Owned nodes keep their existing owned highlight.
- Controller/keyboard focus keeps the existing scale-only navigation presentation.
- Mouse clicks may show the normal momentary pressed state while held, but no selected/toggled highlight remains after release.
- No global focus border or new selection state is introduced.

## Testing

Automated tests will verify:

- The role anchor no longer contains or references a description label.
- The icon and role name remain centered in the existing anchor dimensions.
- Skill nodes have toggle mode disabled.
- Activating available and owned nodes leaves `button_pressed == false`.
- Paid-node activation emits one purchase request; starting skills and the anchor emit none.
- Owned highlighting and mouse-to-controller focus synchronization remain intact.

The focused hub/navigation tests and full GUT suite must pass. The unrelated local `project.godot` change remains outside this work.
