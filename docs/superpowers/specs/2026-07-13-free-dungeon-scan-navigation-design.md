# Free Dungeon Scan Navigation Design

## Purpose

Restore scanning as free map-space targeting. Ordinary dungeon traversal remains deliberate aim-and-confirm because movement increases alert; scan targeting must not require repeated confirm presses to move a reticle between nodes.

This design supersedes the scan-targeting portions of the continuous dungeon controller navigation design. Its traversal behavior remains authoritative and unchanged.

## Interaction Model

Entering scan mode initializes a virtual scanner at the party's current node.

In controller mode:

- the left stick moves the virtual scanner continuously in its exact two-dimensional direction;
- movement is delta-scaled and adjusted for camera zoom so its apparent screen speed stays consistent;
- a visible free scanner cursor follows the virtual position;
- the existing hex reticle separately snaps to the nearest generated hex and identifies the scan center;
- releasing the left stick leaves both scanner position and snapped target in place;
- the semantic confirm action performs the scan at the snapped hex;
- the semantic cancel action exits scan mode without consuming it;
- the D-pad remains a digital movement fallback through the same semantic navigation actions.

Controller code never inspects physical button indices. InputManager remains authoritative for family mappings and glyphs: PlayStation Cross/Circle, Xbox and Steam A/B, and Nintendo A-right/B-bottom.

In keyboard-and-mouse mode, the free controller cursor is hidden. Hovering any generated hex updates the snapped reticle, including hidden hexes, and clicking confirms through the same scan execution path. Switching back to controller mode resumes the virtual scanner from the last mouse-hovered scan hex.

## Scan Eligibility

Every generated map hex is a valid scan center regardless of HIDDEN, REVEALED, or COMPLETED state. This restores the scan's purpose: revealing unknown space without wasting its radius on an already known center.

The scanner cannot leave the generated map's positional bounds. Nearest-hex selection is deterministic, using distance followed by grid coordinates for ties. If the grid has no valid hex, confirmation remains disabled.

Scanning never changes the authoritative party node, movement count, or alert gauge.

## Architecture

Introduce a focused DungeonScanController rather than adding another input and camera subsystem directly to DungeonMap.

The controller owns:

- active scan state;
- virtual scanner world position;
- delta- and zoom-adjusted movement;
- scanner clamping to generated node bounds;
- deterministic nearest-hex selection;
- proportional screen-space camera dead-zone calculations.

DungeonMap continues to own input routing, scene visuals, map state, modal suppression, application of camera targets through map clamping, scan execution, reveal animation, and mouse integration.

This is the first extraction seam for a later dungeon/exploration refactor. It does not reorganize map generation, traversal, interactions, saving, alerts, or ordinary camera behavior. The broader decomposition should be recorded in docs/refactor.md after the seam exists.

## Scanner Presentation

Add a dedicated world-space scanner cursor using assets/graphics/glyphs/cursors/outline/cross_small.svg. It moves continuously and remains visually distinct from the party cursor and the existing snapped hex reticle.

The scanner cursor is visible only during controller scan targeting. The snapped reticle remains the authoritative target presentation for both controller and mouse.

All scan visuals and transient controller state are cleared on confirmation, cancellation, interaction locking, modal ownership, or scene teardown.

## Smart Camera Scrolling

The scanner uses a proportional central dead zone, initially the middle 60 percent of the viewport on both axes. The value is configurable for tuning and scales across desktop, Steam Deck, and mobile resolutions.

Initial tuning values are 600 screen pixels per second for scanner movement and an exponential camera-follow response of 8.0 per second. These remain named configuration values so physical controller testing can tune feel without changing the algorithm.

While the scanner remains inside the dead zone, the camera does not move. When it crosses a boundary, the scan controller calculates the minimum world-space correction needed to return it to that boundary. DungeonMap smoothly approaches the desired position and applies authoritative map-camera clamping.

The camera follows continuously without interrupting scanner input and without creating a new tween every frame.

Right-stick manual camera panning remains available while left-stick scanner input is neutral. While the scanner is moving, manual camera panning is ignored so the two systems cannot fight. If manual panning leaves the stationary scanner outside the viewport or dead zone, the next scanner movement immediately continues while the camera smoothly reacquires it.

## Confirmation and Reveal Lockout

Confirming a scan:

1. validates the currently snapped hex;
2. starts the existing reveal behavior centered on that hex;
3. locks scanner, traversal, and camera input for 0.25 seconds, half of the current 0.5-second reveal animation;
4. clears scan visuals and returns the map to ordinary play after that short lockout.

The reveal animation may continue after input unlocks. The camera remains at the scanned region so the player can inspect the result, manually pan, use Recenter, or continue ordinary movement. Confirming ordinary movement retains its existing camera behavior that returns attention to the party.

The 0.25-second lockout is one named constant rather than a duplicated magic number.

## Existing Camera Code Boundary

The current map already provides camera clamping and ordinary manual pan/recenter behavior. Its exported camera_edge_margin is unused, and it does not currently implement a dead-zone follow system.

This feature adds tested scan-specific dead-zone calculations inside DungeonScanController and reuses DungeonMap only to apply the resulting camera target and final clamp. It does not broadly rewrite the older hybrid zoom, background, or traversal camera code. Suspect legacy camera responsibilities belong in the later dungeon refactor unless a concrete defect blocks this feature.

## State and Modal Rules

- LOADING and LOCKED suppress scanner, confirmation, and camera input.
- Open navigation modals suppress map scanning and preserve modal-owned cursor and hints.
- TARGETING is the only state in which the scan controller is active.
- Cancel exits targeting through the existing scan-cancel signal path.
- Confirmation consumes the pending scan only once.
- Input-family switching cannot confirm a stale target or leave a hidden controller cursor active.

## Testing

Pure controller tests cover delta-scaled arbitrary movement, zoom consistency, bounds clamping, deterministic nearest-node selection including hidden nodes, proportional dead-zone dimensions, minimum camera correction, and reacquisition after manual displacement.

Dungeon integration tests cover controller startup, free-cursor and snapped-reticle separation, continuous movement without confirm presses, semantic confirm/cancel, controller-family independence, D-pad fallback, hidden-hex scanning by controller and mouse, mouse/controller continuity, manual pan rules, modal/locked suppression, brief reveal lockout, camera retention, and unchanged traversal, alert, and save behavior.

Manual DualSense verification covers cursor speed, diagonal response, dead-zone feel, camera smoothing and reacquisition, rapid input-family switching, distant hidden scans, and the absence of camera/scanner fighting.

## Out of Scope

- Refactoring the whole dungeon map.
- Changing scan radius, cost, availability, or reveal content.
- Changing ordinary traversal selection.
- Automatic pathfinding or party movement.
- Rewriting general zoom, background, or hybrid camera behavior.
- Adding controller-specific physical button handling.
