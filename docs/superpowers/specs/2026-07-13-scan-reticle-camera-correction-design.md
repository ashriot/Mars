# Scan Reticle and Camera Correction Design

## Purpose

Replace the current two-cursor scan interaction with a single, stable hex reticle and correct the scan camera behavior. The player must be able to aim a scan, look ahead independently, and return to ordinary exploration without cursor warping or a stranded camera.

This design supersedes the controller cursor, scan camera, and confirmation-camera rules in `2026-07-13-free-dungeon-scan-navigation-design.md`. Its scan eligibility, reveal behavior, semantic input mappings, and ordinary traversal rules remain authoritative unless explicitly changed below.

## Chosen Approach

Use the existing snapped hex reticle as the only visible scan target. Controller directional input advances that reticle through generated hexes in the held direction. Right-stick camera panning remains available simultaneously. A proportional camera safe area smart-follows the reticle only when needed.

Two alternatives were rejected:

- Repairing the visible free cursor would retain two competing indicators and the rectangular world-bound model that caused confusing selection changes.
- Making the scan camera entirely manual would avoid camera contention but could let the selected reticle disappear off-screen during ordinary targeting.

The chosen hybrid keeps the target readable while preserving independent camera inspection.

## Reticle Navigation

The dedicated blue-X scanner cursor is removed from scan presentation and runtime behavior. The existing hex reticle is the sole authoritative target indicator for controller and mouse input.

In controller mode:

- entering scan targeting selects the party's current hex;
- holding the left stick advances the reticle repeatedly through valid generated hexes in the held world-space direction;
- selection uses directional geometry rather than a hidden cursor position or rectangular clamping;
- each step chooses the best hex ahead of the current selection, prioritizing alignment with the held direction and then distance;
- the repeat cadence supports continuous held-stick navigation without requiring repeated confirm presses;
- releasing the stick leaves the reticle on its current hex;
- reversing or changing direction immediately changes the next selection direction;
- the reticle can target hidden, revealed, or completed generated hexes;
- reaching the map edge leaves the reticle on the last valid hex. It never wraps, reverses, or warps to another hex.

The D-pad routes through the same directional selection behavior. Semantic confirm and cancel remain authoritative; code does not inspect controller-specific physical button indices.

In keyboard-and-mouse mode, hovering a generated hex moves the same reticle and clicking confirms it. Input-family switching preserves the currently selected hex without creating or revealing another cursor.

## Camera Behavior During Targeting

The camera and reticle accept input concurrently:

- the left stick moves the scan reticle;
- the right stick pans the camera at all times during scan targeting;
- neither input suppresses or cancels the other.

The camera uses the existing proportional safe area. Reticle movement inside that box does not move the camera. When reticle movement places the reticle outside the box, the camera smoothly applies only the minimum correction required to bring it back to the nearest boundary.

Manual right-stick panning establishes the camera's new position. Releasing the right stick does not automatically undo that pan or recenter the camera. Smart-follow resumes only if subsequent reticle movement leaves the reticle outside the safe area. This lets the player pan ahead and inspect the map without the camera fighting their input.

When manual pan and reticle movement occur in the same frame, right-stick panning wins and smart-follow does not counteract it. Releasing the right stick leaves the camera where the player put it, even if the reticle is then outside the safe area. Smart-follow reacquires the reticle only when the player subsequently moves the reticle again. Camera bounds remain authoritative.

## Confirmation, Cancellation, and Return

Confirming a valid scan:

1. captures the currently selected hex;
2. clears scan-targeting visuals and input state;
3. runs the existing reveal centered on that hex;
4. preserves the existing brief reveal input lock;
5. smoothly recenters the camera on the party when the brief lock ends;
6. returns to ordinary exploration input.

The camera does not remain stranded at the scanned region. The reveal animation may finish independently after the short lock, as it does today.

Canceling scan targeting consumes no scan and smoothly returns the camera to the party immediately. Scene teardown, modal takeover, or another state transition must also clear scan targeting without leaving the scan focus mode active.

## Architecture

`DungeonScanController` remains the focused owner of scan selection policy, but its free world position, cursor speed, rectangular bounds, and nearest-node selection responsibilities are removed. It instead owns:

- the active selected hex;
- directional candidate scoring;
- stick engagement and repeat timing;
- stable edge behavior.

`DungeonMap` continues to own input routing, reticle animation, map state, scan execution, mouse hover integration, and coordination with `DungeonCameraController`.

`DungeonCameraController` continues to own panning, clamping, proportional safe-area follow, and smooth recentering. Scan code requests those policies rather than directly manipulating camera position.

The obsolete `ScannerCursor` scene node and its blue-X texture reference are removed if no other runtime path uses them.

## Failure and State Rules

- An empty map or missing selected node disables confirmation without crashing.
- `LOADING` and `LOCKED` suppress scan navigation and camera input.
- Open navigation modals retain input ownership.
- Scan confirmation is accepted only once.
- A held direction at the map edge produces no selection change and no repeated animation.
- A camera clamped at a map edge does not feed back into reticle selection.
- Camera position and screen transforms never alter the authoritative selected hex.

## Testing

Focused controller tests cover directional candidate selection, diagonal intent, held-input repeat, immediate direction changes, deterministic tie-breaking, and stable behavior at every map edge.

Dungeon integration tests cover:

- no visible or active blue-X scanner cursor;
- one reticle shared by controller and mouse;
- hidden-hex scan eligibility;
- simultaneous left-stick targeting and right-stick panning;
- no camera movement while the reticle remains inside the safe area;
- minimum smart-follow after it crosses the boundary;
- manual pan retention after right-stick release;
- smart-follow reacquisition only after the reticle leaves the safe area;
- smooth party recenter after confirmation and cancellation;
- modal, lock, teardown, and input-family transitions;
- unchanged scan reveal, movement, alert, and save behavior.

Manual DualSense verification covers directional feel, repeat cadence, diagonal selection, map-edge stability, simultaneous aim and pan, safe-area behavior, confirmation return, cancellation return, and mouse/controller switching.

## Out of Scope

- Changing scan radius, cost, reveal content, or availability.
- Changing ordinary traversal controls or camera behavior.
- Refactoring map generation or the wider dungeon state machine.
- Adding new cursor art.
- Changing controller-family mappings or glyph selection.
