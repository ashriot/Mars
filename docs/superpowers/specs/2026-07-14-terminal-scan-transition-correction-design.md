# Terminal-to-Scan Transition Correction Design

## Goal

Make terminal protocol input unambiguous and make controller scanning use a stable world-space aim that stays centered during scan movement and remains anchored while the camera is deliberately panned away.

This design supersedes the terminal focus/typing behavior and the pointer-presentation and selection-ownership portions of `2026-07-14-controller-driven-scan-cursor-design.md`. Existing scan effects, radius, costs, confirmation, cancellation, reveal timing, and return-to-party behavior remain unchanged.

## Observed Failure

The terminal currently combines focus navigation with direct shortcuts. A row can appear selected while the controller's face and shoulder buttons also represent fixed protocols, making it unclear whether Cross/A activates the focused row or its displayed shortcut.

The Scan choice also queues the terminal for deletion but starts targeting before the terminal has actually left the tree. Its modal registration can therefore remain active during the transition and cause the map to cancel or suppress the new targeting state.

Controller scanning originally relied on `Area2D.mouse_entered` to update the selected hex after warping the system pointer. Later screen-space pointer and edge-scroll behavior caused the cursor and camera to move simultaneously, producing apparent acceleration, feedback, and selection warping. The corrected model stores one world-space aim and projects it for display.

## Terminal Input Model

Normal protocol selection uses direct shortcuts or direct mouse clicks only.

- Protocol rows are not keyboard/controller focus targets.
- Up/down navigation does not move among protocol rows.
- Cross/A always invokes the protocol assigned to Cross/A; it never activates a separately highlighted row.
- Square/X, Triangle/Y, L1, and R1 likewise invoke only their displayed semantic protocol actions.
- Mouse hover shows the existing terminal caret/highlight presentation so clickable rows remain obvious.
- Mouse hover is visual presentation only; it does not assign GUI focus or alter controller shortcut meaning.
- A mouse click activates the hovered protocol through the existing row activation path.
- Extraction confirmation remains an explicit modal choice. Its Confirm and Cancel controls may receive focus because Cross/A and Circle/B have unambiguous confirmation meanings in that state.
- Circle/B continues to close or back out according to the current terminal state.

The typing animation is short and is no longer skippable through protocol input:

- protocol and extraction shortcuts received during `TYPING` are consumed without activating a protocol or completing the animation;
- mouse protocol clicks during `TYPING` are inert;
- the animation completes normally and moves the terminal to `READY`;
- Circle/B may still close the terminal during the animation.

## Terminal-to-Scan Lifecycle

Selecting Scan removes transient terminal overlays from the scene tree synchronously before scan targeting begins. Removing the terminal also removes its navigation modal registration before `DungeonMap.start_targeting_mode()` is called.

The transition order is:

1. commit the Scan protocol exactly once;
2. synchronously remove the terminal overlay and queue it for deletion;
3. connect the one-shot scan success and cancellation handlers;
4. start scan targeting;
5. allow map processing only after no terminal modal remains.

This preserves the existing behavior where canceling a scan reopens the current terminal.

## Scan Cursor and Selection

The controller drives a dungeon-map-local world aim with the left stick or D-pad. This is continuous cursor movement, not hex-to-hex controller navigation and not a warp of the physical OS mouse:

- analog magnitude controls continuous world-aim velocity through the existing input dead zone;
- D-pad input drives the same world aim at full digital magnitude;
- the existing custom navigation cursor is drawn at the world aim's projected screen position;
- the projected screen pointer and custom cursor are presentation of one controller-owned world authority;
- controller movement never changes the physical OS mouse position.

While controller mode is active, the OS cursor is hidden and the custom controller cursor remains visible during scan targeting. Mouse motion by itself does not switch input mode. A physical mouse-button click switches to keyboard-and-mouse mode, hides the custom controller cursor, and reveals the OS cursor at the physical mouse position. The OS cursor does not inherit the controller cursor's position.

Keyboard input alone remains part of keyboard-and-mouse mode. The mouse activation rule is intentionally click-based so incidental or hidden mouse motion cannot steal controller presentation.

Hex selection no longer depends solely on Godot generating a new mouse-motion hover event:

- physical mouse hover signals and controller world-aim resolution both call one shared `DungeonMap` selection method;
- after controller aim movement, `DungeonMap` resolves the `MapNode` at the global-world query point using the map's actual `Area2D` collision shapes;
- when a `MapNode` is beneath the pointer, the shared method updates `DungeonScanController.selected_node`, `_controller_preview_node`, and the snapped reticle;
- when the pointer crosses a gap, the last valid selected hex remains selected, matching existing mouse behavior;
- selected-node state never drives aim position or camera position.

The collision query is a necessary engine integration seam, not a second set of targeting rules. It reuses the same collision geometry and the same selection method as mouse hover.

## Camera Behavior

- While left-stick or D-pad scan movement is active, the camera is attached to the world aim and keeps its projected cursor centered.
- Releasing navigation input stops world-aim and attached-camera movement immediately.
- With left input neutral, right-stick input detaches and pans the camera without moving the world aim or changing the selected hex.
- The cursor and reticle remain anchored to that world target and therefore move together on screen as the camera pans.
- Resuming left-stick or D-pad movement takes priority over right-stick input, smoothly returns the camera to the world aim, and restores the centered lock.
- No camera motion feeds back into the stored world aim.

## Architecture

`Terminal` owns protocol presentation, shortcut-state gating, mouse clicks, hover presentation, and extraction confirmation focus.

`GameManager` owns synchronous terminal-overlay teardown before scan startup and the existing scan outcome connections.

`DungeonScanController` continues to own scan speed, active state, projected pointer presentation, and the last supplied selected node.

`InputManager` owns click-based mouse-mode activation and ignores mouse motion as a mode-switching signal.

`DungeonMap` owns the controller world aim, visible custom scan-cursor projection, collision resolution, the shared scan-selection boundary, and camera-policy orchestration.

`DungeonCameraController` continues to own pan motion, zoom interaction, and authoritative map clamping.

## Testing

Automated coverage must prove:

- protocol rows cannot receive normal GUI focus but still respond to mouse hover and click;
- directional GUI navigation cannot change the active terminal protocol;
- every semantic shortcut invokes only its assigned protocol;
- protocol input during typing neither skips the animation nor commits a choice;
- Scan removes the terminal overlay/modal before targeting begins;
- controller pointer resolution uses a real `MapNode` collision shape and the shared selection boundary;
- analog and D-pad input move the stored world aim at the expected magnitude while its projected cursor remains centered under attached-camera movement;
- mouse motion alone preserves controller mode, while a physical mouse-button click activates keyboard-and-mouse mode and restores the OS cursor at its physical position;
- right-stick camera panning leaves the world aim and selected hex unchanged while their cursor and reticle projections move together on screen;
- resumed left input smoothly reattaches the camera without warping the aim or reticle;
- neutral input still stops camera motion immediately;
- scan cancel reopens the terminal and scan confirm completes the interaction once.

Manual DualSense acceptance must verify the terminal shortcut model, visible custom scan cursor, mouse hover presentation, terminal-to-scan transition, centered camera lock, right-stick detachment, smooth left-stick reattachment, mouse/controller handoff, confirmation, and cancellation.

## Out of Scope

- Changing terminal protocol effects or balance.
- Changing scan radius, cost, reveal effects, or rewards.
- Changing ordinary dungeon traversal.
- General release cursor policy outside controller-owned cursor interaction.
- Refactoring the wider terminal, dungeon, or navigation architecture.
