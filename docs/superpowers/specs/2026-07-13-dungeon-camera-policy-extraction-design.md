# Dungeon Camera Policy Extraction Design

## Purpose

Extract the stable dungeon camera rules from `DungeonMap` into a focused runtime controller. This is the first general-purpose step in decomposing dungeon exploration orchestration, and it must preserve current camera behavior exactly rather than tune or redesign it.

This work addresses GitHub issue #3. It follows the scan-specific seam established by `DungeonScanController` and prepares `DungeonMap` to become an orchestrator instead of the implementation site for every exploration concern.

## Scope and Behavioral Contract

The extraction covers general dungeon camera policy:

- map-space camera clamping;
- manual camera panning;
- recentering on the party;
- bounded zoom and zoom tween behavior;
- party-follow positioning;
- proportional scan dead-zone following;
- cancellation of active camera motion;
- explicit switching between party and scanner focus.

The implementation must retain the current numerical tuning, input gates, camera destinations, animation timing, and background behavior. No camera feel, scan behavior, traversal behavior, or input mapping is intentionally changed by this refactor.

## Ownership Boundary

Introduce `DungeonCameraController` as a regular runtime `Node`, created and configured by `DungeonMap`.

`DungeonCameraController` owns:

- the live `Camera2D` position and zoom policy;
- clamping camera positions against the current map bounds;
- manual pan calculations and application;
- party recenter and follow calculations;
- scanner dead-zone calculations and smooth scanner follow;
- bounded zoom calculations and camera-owned tweens;
- cancellation of camera-owned motion before a new operation or external presentation takes control;
- the current camera focus mode.

`DungeonMap` continues to own:

- map generation and authoritative map state;
- traversal legality and execution;
- scan lifecycle and scan command legality;
- input routing and modal/state gates;
- the authoritative current party node;
- map interaction dispatch;
- HUD, grid, shader, parallax, and background presentation;
- battle-entry and battle-exit presentation transitions;
- save and restore orchestration.

`DungeonScanController` becomes scanner-specific. It continues to own active scan state, virtual scanner movement, scanner bounds, and deterministic nearest-node selection. The proportional screen-space dead-zone calculation moves to `DungeonCameraController`, because it is camera follow policy rather than scanner selection policy.

## Runtime Interface

`DungeonMap` configures the controller with the live `Camera2D`, relevant background or viewport geometry, map bounds, and the existing exported tuning values. Existing exported values remain on `DungeonMap` so scene configuration and editor-facing ownership do not churn during this extraction.

The camera controller exposes focused operations equivalent to the existing behavior:

- configure or refresh geometry and tuning;
- process manual pan from an already-authorized direction and delta;
- recenter or follow the party position;
- follow the scanner position using the proportional dead zone;
- apply bounded zoom around the existing anchor behavior;
- clamp an arbitrary candidate camera position;
- cancel camera-owned motion;
- switch focus mode between party and scanner.

The controller receives decisions, positions, and deltas. It does not inspect `MapState`, poll raw input, decide whether a modal permits movement, select scan targets, or execute traversal. This keeps input and gameplay authority in `DungeonMap` while centralizing the camera calculations they invoke.

## Focus Modes and Motion Ownership

Use an explicit camera focus enum with two modes:

- `PARTY`: ordinary exploration camera behavior follows or recenters on the authoritative party node.
- `SCANNER`: scan navigation keeps the virtual scanner inside the existing proportional dead zone.

Entering and leaving scan targeting changes this mode through `DungeonMap`. The controller must not infer focus from scanner visibility or map state.

Only one subsystem owns live camera motion at a time:

- camera-controller operations cancel incompatible camera-controller tweens before starting new motion;
- live scanner following owns camera position continuously and does not create a new position tween every frame;
- scan zoom may tween zoom while scanner follow continues to own position;
- ordinary party zoom may retain the existing position-and-zoom tween behavior;
- battle transitions first cancel camera-controller motion, then temporarily let `DungeonMap` own the battle presentation transition;
- returning from battle restores ordinary camera control through the existing map lifecycle.

This avoids competing tweens without moving battle, HUD, grid, shader, or background-transition responsibilities into the controller.

## Geometry and Background Boundary

Camera clamping remains based on the same map and viewport geometry used today. The formulas move behind `DungeonCameraController`, but their inputs and outputs do not change.

Background sizing, transform updates, parallax presentation, and battle fades remain in `DungeonMap`. The controller may receive the geometry needed to calculate camera limits, but it does not become a general scene-presentation manager.

The existing exported camera tuning remains unchanged, including zoom step and bounds, smooth speed, pan speed, scan dead-zone proportion, and scan follow response. The currently unused `camera_edge_margin` is not given new behavior as part of this refactor.

## Input and State Flow

The flow remains:

1. Godot input reaches `DungeonMap`.
2. `DungeonMap` applies map-state, modal, interaction, and device-family gates.
3. An authorized camera command is delegated to `DungeonCameraController`.
4. The controller calculates and applies the resulting `Camera2D` state.

This extraction does not add direct physical controller-button handling. Semantic input actions and `InputManager` mappings remain authoritative.

## Migration Strategy

Move one cohesive camera behavior at a time behind the controller while keeping the existing `DungeonMap` entry points as thin delegates. Private math helpers move only when the behavior they support moves.

The intended sequence is:

1. add focused unit tests that capture the current camera math and mode rules;
2. introduce and configure `DungeonCameraController` without changing behavior;
3. move clamping and manual pan;
4. move party recenter/follow and bounded zoom;
5. move proportional scanner following out of `DungeonScanController`;
6. centralize camera tween cancellation and focus switching;
7. retain battle presentation delegation and verify the full dungeon integration suite;
8. remove superseded private camera helpers from `DungeonMap` only after all callers use the controller.

At each step, existing public or input-facing behavior stays callable through `DungeonMap`. The migration should not combine unrelated cleanup with the extraction.

## Testing

Focused `DungeonCameraController` unit tests protect:

- camera clamping at each map boundary and zoom level;
- manual pan delta and final clamping;
- zoom min/max enforcement and existing anchor calculations;
- party recenter and hybrid positioning;
- proportional scanner dead-zone dimensions and minimum correction;
- scanner reacquisition after manual displacement;
- party/scanner focus transitions;
- cancellation and replacement of camera-owned tweens;
- scanner position follow remaining independent from zoom tweening.

Existing scan-controller tests are adjusted so they protect scanner movement, bounds, and nearest-node selection without owning camera dead-zone policy.

Existing dungeon integration tests continue to protect:

- state and modal input gating;
- scan entry, movement, reveal, and exit behavior;
- manual pan, recenter, mouse wheel, magnify gesture, and controller camera input;
- ordinary traversal and backtracking camera behavior;
- battle camera entry and restoration;
- save restoration and authoritative current-node behavior;
- unchanged background and map presentation.

The complete automated suite must pass after the extraction. Manual verification should compare party movement, manual pan, zoom, recenter, scan follow/reacquisition, battle transitions, and controller behavior against the current build, with no intentional feel changes.

## Documentation Follow-up

After implementation, update `docs/refactor.md` to mark general camera policy as an extracted boundary and record the next evidence-backed dungeon responsibility. Do not imply that the broader dungeon decomposition is complete.

## Out of Scope

- Tuning camera speed, zoom, dead-zone size, easing, or animation timing.
- Changing scan targeting, scan radius, reveal rules, or lockout behavior.
- Changing traversal legality, alert cost, or party movement.
- Refactoring map generation, reveal/vision, interactions, saving, or traversal state.
- Moving battle fades or background presentation into the camera controller.
- Reorganizing the dungeon scene into a separate camera/background rig.
- Adding new camera features or activating the unused edge-margin setting.
- Changing input mappings or controller-family behavior.
