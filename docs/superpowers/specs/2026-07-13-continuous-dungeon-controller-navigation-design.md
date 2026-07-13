# Continuous Dungeon Controller Navigation Design

## Goal

Make dungeon-map controller navigation feel like continuous analog aiming instead of repeated keyboard-style direction presses. The player holds the left stick toward an adjacent node, presses the controller confirm button to move, and can keep holding or rotating the stick while repeatedly confirming to traverse the map.

Keyboard-and-mouse play remains mouse-driven on the map. Keyboard input does not preview or confirm map nodes through the directional navigation system.

## Current Failure

The map currently reads the navigation vector every frame but only reevaluates selection when the direction was previously neutral or changes by a fixed angular amount. The selected preview persists when the stick returns to neutral. Confirming clears the preview but leaves the remembered direction unchanged.

Consequently, a stick held through a completed-node move is not reevaluated from the new current node. The player must release and tilt again or wiggle the stick far enough to cross the angular-change threshold. Candidate changes are sampled as isolated direction changes rather than derived continuously from the current stick and current node. This event-like state model is the source of the janky behavior; the existing reticle animation is not.

## Input Responsibilities

### Controller Mode

The left stick supplies a continuous two-dimensional direction:

- stick magnitude determines only whether the input is inside or outside the configured deadzone;
- stick angle determines which eligible node is the best directional match;
- the reticle always lands on a node and never rests partway between nodes;
- rotating the held stick may change candidates without first returning to neutral.

Controller D-pad input remains a digital accessibility fallback through the same directional actions. It does not define or limit the analog-stick behavior.

### Keyboard-and-Mouse Mode

Mouse hover and click remain the map's node-selection and confirmation controls. WASD and arrow-key input do not feed dungeon node preview or movement.

This intentionally narrows the dungeon-specific behavior described by the earlier keyboard-navigation parity design. Standard UI screens still support keyboard focus navigation, and dungeon camera bindings remain unchanged.

## Continuous Selection Model

While the map is in an input-enabled state and `InputManager` reports controller mode, the map reconciles the controller preview with the current input every frame:

1. Read the current navigation vector.
2. If it is neutral, clear the candidate and begin the centered-reticle behavior.
3. Otherwise, compute eligible candidates using the existing traversal or scan-targeting rules.
4. Choose the candidate most closely aligned with the stick angle.
5. Retarget only when the chosen candidate or current node changes.

The existing `DungeonNavigation.closest_by_angle` policy remains the basis for directional choice. A small angular hysteresis keeps the current candidate until another candidate is clearly better, preventing noisy stick input from flickering between neighboring nodes. The hysteresis must affect only presentation stability; it must not make a clearly intended direction unreachable.

If no eligible node lies in the chosen direction, the preview is cleared and confirm is disabled. The selection calculation must not restart the reticle tween every frame when the candidate has not changed.

## Reticle Presentation

Selecting a candidate uses the existing approximately 0.15-second reticle animation to move directly onto that node.

When the stick returns to neutral:

1. the preview candidate is cleared immediately;
2. the reticle animates back to the current node;
3. it remains visible briefly;
4. it fades out.

New controller input or mouse hover cancels any pending centered fade and takes control of the reticle immediately. Switching to keyboard-and-mouse mode clears controller preview state so stale controller selection cannot be confirmed.

The player cursor continues to indicate the party's actual location. The reticle indicates only a pending controller destination or the brief return-to-center transition.

## Confirming and Chained Movement

The controller confirm button acts only when a valid preview exists. Confirmation continues through the existing validated click/movement path so controller and mouse traversal obey the same revealed, completed, adjacency, and map-state rules.

After confirmation:

- the current preview is consumed;
- the movement updates `current_node` through the existing movement path;
- completed-node traversal becomes input-enabled as it does today;
- on the next eligible frame, a still-held stick is reevaluated from the new `current_node` even when its angle has not changed.

This permits rapid confirm taps while holding or rotating the stick to retrace completed nodes. A newly entered combat, terminal, reward, or other unresolved node still locks map input normally. When that interaction finishes and the map unlocks, a still-held stick is reevaluated from the new node.

Releasing the stick before confirmation clears the preview, so confirm has no movement target.

## Map States and Scanning

`LOADING` and `LOCKED` states continue to suppress controller selection and confirmation. They must not permanently preserve a stale preview.

`TARGETING` continues using its broader existing candidate rule for revealed scan targets, but it uses the same continuous angle, neutral return, and confirm behavior. Cancel still exits targeting through the existing scan-cancel path.

Normal traversal rules, backtracking eligibility, revisit alert reduction, interaction dispatch, and camera behavior do not change.

## Implementation Boundary

The change should remain localized to dungeon navigation state, its directional helper where hysteresis requires it, relevant automated tests, and controller documentation. It should replace the stale `_last_controller_direction` event gate with state derived from the active input vector, candidate, and current node.

This work does not add pathfinding, automatic multi-node travel, proportional analog reticle positioning, keyboard map traversal, or new reticle artwork.

## Testing

Automated regressions must verify:

- a neutral stick clears the preview and returns the reticle to the current node;
- a held direction selects without requiring repeated direction events;
- rotating directly between eligible directions changes the candidate;
- candidate stability prevents boundary noise from rapidly alternating nodes;
- an unchanged held direction is reevaluated after movement changes the current node;
- repeated confirms can traverse a chain of completed nodes;
- entering and leaving a locked interaction does not permit stale confirmation and resumes held-stick evaluation correctly;
- keyboard input in keyboard-and-mouse mode does not preview or move between nodes;
- mouse hover and click still take over cleanly after controller navigation;
- controller D-pad fallback still selects eligible nodes;
- scan targeting still selects, confirms, and cancels valid targets;
- existing mouse/controller traversal parity, backtracking alert costs, and interaction validation remain unchanged.

The manual controller checklist should explicitly cover slow stick rotation around a node, release-to-center behavior, rapid confirm tapping across completed nodes, and resuming after an interaction.

## Verification

Completion requires focused dungeon navigation tests, the full Godot 4.6.3/GUT 9.6.1 suite, headless import validation, and `git diff --check`. Manual verification should be performed with the connected PS5 controller because feel, deadzone behavior, and candidate-boundary stability cannot be fully established by automated tests.
