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

## Modal Teardown and Hint Lifecycle

Closing the party menu normally should continue to pop the modal and restore focus to the hub. Removing the party menu because its scene is exiting is different: the navigation layer must discard that modal entry without restoring focus or publishing hints into controls that are also leaving the tree.

- Add an explicit modal-removal path that prunes a modal entry without focus restoration.
- `PartyMenu._exit_tree()` uses removal; the normal close path continues to use `pop_modal()` and restore focus.
- Removing a modal must clear any presentation owned by that modal and leave remaining stack entries valid.
- `ActionHint.configure()` stores its input independently of child-node readiness and applies it immediately when ready or later from `_ready()`.
- Hint configuration must not dereference null `@onready` child controls.
- No deferred callback may publish stale hints after the owning scene has exited.

## Testing

Automated tests will verify:

- The role anchor no longer contains or references a description label.
- The icon and role name remain centered in the existing anchor dimensions.
- Skill nodes have toggle mode disabled.
- Activating available and owned nodes leaves `button_pressed == false`.
- Paid-node activation emits one purchase request; starting skills and the anchor emit none.
- Owned highlighting and mouse-to-controller focus synchronization remain intact.
- Normal modal close restores hub focus and hints.
- Party-menu scene teardown removes its modal without restoring focus or publishing hub hints.
- Configuring an `ActionHint` before it enters the scene tree applies its data safely after `_ready()`.
- Repeated modal removal/pop operations remain idempotent and do not corrupt the modal stack.

The focused hub/navigation tests and full GUT suite must pass. The unrelated local `project.godot` change remains outside this work.
