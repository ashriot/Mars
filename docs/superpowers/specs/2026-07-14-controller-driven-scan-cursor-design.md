# Controller-Driven Scan Cursor Design

## Goal

Replace controller scan node-stepping with a visible, continuously moving screen-space cursor. Mouse and controller scanning must use the same hover-selection path: the cursor moves freely, while the existing hex reticle snaps to the generated hex underneath it.

This design supersedes the controller-selection and scan-camera input portions of `2026-07-13-scan-reticle-camera-correction-design.md`. That design's scan eligibility, confirmation, cancellation, reveal, lockout, and return-to-party rules remain authoritative unless changed here.

## Root Cause

The current scan implementation has two competing selection authorities:

- `DungeonScanController.process_direction()` directly changes the selected hex for controller input.
- `MapNode.mouse_entered` calls `DungeonMap._on_node_hovered()`, which also changes the scan selection.

When smart-follow moves the camera, world-space hexes slide beneath the stationary system mouse. Their hover events overwrite the controller-selected hex, creating the visible warp back toward the mouse position. Preventing hover in controller mode would hide the symptom but preserve the unwanted square-to-square controller feel.

## Chosen Interaction

Scanning uses one visible pointer and one snapped target:

- the system mouse cursor is the continuously moving pointer;
- the existing hex reticle is the authoritative scan target;
- left-stick or D-pad direction moves the pointer smoothly in screen space;
- `MapNode.mouse_entered` is the sole path that changes the selected scan hex for both controller and mouse;
- the reticle snaps immediately to the hovered generated hex;
- no controller-only node stepping, hidden directional selection, blue-X cursor, or second hit-test path remains.

The system cursor remains visible during this pre-alpha development phase, matching the current repository cursor policy. A later release-specific custom cursor or OS-cursor hiding pass is outside this work.

## Pointer Lifecycle

Entering scan targeting initializes the cursor at the viewport position of the party's current hex. The scan controller stores its screen-space pointer position and clamps it inside the usable viewport rectangle.

During controller input:

1. read the semantic navigation vector;
2. apply the controller dead zone through the existing input actions;
3. limit the vector length to one;
4. move the screen-space pointer by configured pixels per second times frame delta;
5. clamp the pointer inside the viewport;
6. mark the destination with `InputManager.expect_mouse_warp()`;
7. call the viewport's mouse-warp API.

Expected synthetic mouse motion must not change the global mode from controller to keyboard/mouse. Physical mouse motion remains meaningful input and takes over from the cursor's current location. Moving the stick again returns to controller mode and continues from that same mouse position.

Releasing the stick leaves the cursor and reticle where they are. Pointer movement and edge scrolling stop immediately.

## Selection Ownership

`DungeonMap._on_node_hovered()` remains the common selection boundary. While targeting, a hover from either a physical mouse or controller-driven mouse warp updates `DungeonScanController.selected_node`, synchronizes `_controller_preview_node`, and snaps the reticle without animation.

Camera motion may move a different hex under a stationary edge cursor. Updating the reticle to that newly hovered hex is intentional in this model because the visible cursor, rather than a separate hidden controller selection, owns targeting.

If the cursor crosses a gap between hexes, the last valid hovered hex remains selected, matching the current mouse behavior. Confirmation remains disabled only when no valid scan hex has ever been selected.

## Camera Behavior

The existing proportional central safe area remains the edge-scroll boundary.

- Pointer movement inside the safe area does not move the camera.
- While left-stick or D-pad direction is non-zero and the pointer is outside the safe area, the camera smoothly scrolls in that direction using the existing scan-follow response and authoritative map clamping.
- If the pointer reaches the viewport boundary, continued directional pressure keeps scrolling the camera while the cursor stays clamped at the edge.
- Releasing the navigation direction stops edge scrolling immediately, even when the cursor remains outside the safe area.
- Right-stick manual panning remains available. Non-zero right-stick input wins over scan edge-follow in the same frame.
- When right-stick input ends, edge-follow resumes only if left-stick or D-pad direction is actively held outside the safe area.

As the camera moves, hexes passing beneath the visible cursor naturally update hover selection and the snapped reticle. There is no camera-driven attempt to restore a separate selected hex.

## Architecture

`DungeonScanController` owns only scan-specific pointer state:

- active state;
- screen-space pointer position;
- configured cursor speed;
- viewport clamping;
- the last valid hovered `selected_node` supplied by `DungeonMap`.

It no longer owns directional neighboring-hex scoring, held-step repeat timing, or camera policy.

`DungeonMap` remains the orchestrator for:

- semantic input routing;
- converting the party hex to the initial viewport cursor position;
- requesting controller-generated mouse warps;
- receiving the common node-hover signal;
- reticle presentation;
- invoking camera edge-follow or right-stick pan;
- scan confirmation, cancellation, and state cleanup.

`DungeonCameraController` continues to own camera movement, smoothing, viewport-safe-area calculations, zoom handling, and map clamping. It receives the current pointer-derived world position only while active navigation requests edge scrolling.

`InputManager` continues to own input-family detection and expected-warp suppression. No physical controller button indices are inspected by scan code.

## State and Failure Rules

- `LOADING`, `LOCKED`, open modals, scene teardown, scan confirmation, and scan cancellation stop controller-driven pointer movement.
- Starting without a current hex fails safely and does not warp the cursor.
- An empty or invalid node set leaves confirmation unavailable.
- Expected synthetic mouse motion never changes the active input family.
- Genuine physical mouse movement always takes ownership immediately.
- Camera clamping cannot modify pointer position or directly assign scan selection.
- Scan confirmation remains one-shot and uses the last valid hovered hex.
- Existing scan radius, availability, cost, reveal behavior, alert behavior, and save behavior do not change.
- Confirmation and cancellation keep the existing camera return and brief reveal lock behavior.

## Testing

Focused scan-controller tests cover:

- initialization at an exact screen position;
- delta-scaled analog and digital movement;
- diagonal input limited to the configured speed;
- viewport-edge clamping;
- neutral input preserving pointer position;
- hover-supplied selection state;
- stop/reset behavior.

Input and integration tests cover:

- controller-generated mouse warps remaining in controller mode;
- controller and physical mouse using the same hover-selection method;
- the reticle snapping to the hovered hidden, revealed, or completed hex;
- removal of neighboring-hex stepping and repeat behavior;
- camera movement beginning only while navigation is actively held outside the safe area;
- camera movement stopping on release;
- continued camera scrolling at a clamped viewport edge;
- right-stick pan winning over edge-follow in the same frame;
- camera motion allowing newly hovered hexes beneath the cursor to become the target without a second selection restoring the old hex;
- seamless physical-mouse takeover and controller resumption from the current cursor position;
- unchanged confirmation, cancellation, modal suppression, reveal, and party-return behavior.

Manual DualSense verification covers analog speed and diagonal feel, pointer visibility, reticle snapping, edge scrolling and release, right-stick override, hidden-hex selection, mouse/controller handoff, confirm, and cancel.

## Rejected Alternatives

### Separate Virtual Cursor and Explicit Hit Testing

A dedicated controller cursor with its own map query could reproduce the desired appearance, but it would duplicate mouse hover selection and recreate synchronization risk between two targeting paths.

### Reticle-Only Neighbor Stepping with Hover Suppression

Ignoring hover while in controller mode would prevent the observed overwrite, but the controller would still jump directly among hexes rather than driving a tactics-style cursor. It fixes the symptom rather than the interaction model.

## Out of Scope

- Changing ordinary dungeon traversal controls.
- Changing scan effects, radius, cost, availability, reveal timing, or rewards.
- Changing controller-family glyph mappings.
- Replacing the system cursor with new art or hiding it for release.
- Refactoring map generation or the wider dungeon state machine.
- Retuning right-stick pan, zoom, or ordinary camera behavior.
