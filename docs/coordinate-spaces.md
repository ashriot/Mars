# Coordinate Spaces and Positioning

Use an explicit coordinate space for every position. Cursor, UI, camera, and world positions may share the `Vector2` type, but they are not interchangeable.

## Coordinate spaces

- **Global world space** — Coordinates used by `World2D` physics queries. These include transforms inherited from `WorldLayer`, `GameManager`, and the `DungeonMap` root.
- **Dungeon-map local space** — Positions of map nodes, the party marker, the scan reticle, and the dungeon camera relative to `DungeonMap`. `camera.position` uses this space.
- **Viewport screen space** — Logical viewport pixels with `(0, 0)` at the top-left. `Viewport.get_mouse_position()` and the projected presentation of a controller-owned cursor use this space.
- **UI canvas space** — Positions owned by `Control` nodes and `CanvasLayer`. Convert through the relevant control or canvas instead of assuming these values are world positions.
- **Physical OS pointer state** — The operating-system mouse position. It is independent from the controller-owned software cursor and must not be used as controller scan authority.

Name ambiguous values with their space, such as `pointer_screen_position`, `query_global_world_position`, `pointer_map_position`, or `viewport_size`.

## Responsive display spaces

Redshift keeps `1920x1080` as its authoring reference canvas and uses Godot's `canvas_items` stretch mode with `expand` aspect handling. Do not treat that reference size as the physical window size or assume that every logical viewport is `1920x1080`.

- **Physical window size** is the output size reported by `DisplayServer`. `DisplayProfile` classifies the window as compact when its width is `1366` pixels or less or its height is `800` pixels or less. A compact display uses its available size in borderless fullscreen at startup; a larger desktop display defaults to a `1920x1080` window.
- **Expanded logical canvas** is the root viewport's visible logical size after stretch handling. A native `1280x800` output maps to a `1920x1200` logical canvas; a `1920x1080` output maps to `1920x1080` logical pixels.
- **Centered world safe rectangle** is the largest centered rectangle, no larger than the `1920x1080` reference, returned by `DisplayProfileService.safe_rect_for()`. Authored world subjects and critical staging stay inside it without nonuniform stretching. At the Deck target, the safe rectangle is `Rect2(0, 60, 1920, 1080)` in logical coordinates.
- **Full-viewport UI** belongs to `Control` nodes or `CanvasLayer` overlays that anchor against the complete expanded logical canvas. Backgrounds, cameras, fades, HUD edge groups, responsive overlays, and modal backdrops may cover or use the additional 16:10 area outside the world safe rectangle.

`Main.apply_display_layout()` applies the centered safe rectangle to `WorldLayer`; it does not redefine viewport coordinates for `MenuLayer` or full-viewport UI. Convert world, screen, and control coordinates through their actual canvas boundaries. In particular, do not offset a full-viewport control by the world safe rectangle, and do not use a control's expanded-canvas position directly for a world physics query.

## Dungeon scan conversions

Convert a viewport pointer from screen space to global world space before a physics query:

```gdscript
global_world_position = get_canvas_transform().affine_inverse() * screen_position
```

Camera-follow calculations compare against `camera.position`, so convert that global point into dungeon-map local space first:

```gdscript
map_position = to_local(global_world_position)
```

The reverse global-world-to-screen conversion is:

```gdscript
screen_position = get_canvas_transform() * global_world_position
```

Dungeon scan conversion is centralized in `DungeonMap._scan_screen_to_global_world()` and `DungeonMap._scan_screen_to_map_position()`. The controller scan aim is already stored in dungeon-map local space, but it must be converted to global world space before a physics query and projected to screen space before drawing its cursor. Do not duplicate or merge those boundaries.

## Cursor and reticle ownership

- The hardware pointer is always driven by physical mouse input and is never warped by keyboard or controller navigation.
- Ordinary controller navigation hides that pointer and uses GUI focus, map reticles, or actor highlights.
- The scan software pointer is the sole controller-positioned pointer; it consumes an explicit projected screen position and never feeds back into OS pointer state.
- Mouse motion is ignored during controller ownership. A consumed click transaction performs controller-to-mouse ownership handoff.

During controller scanning:

- `DungeonMap._controller_scan_map_position` is the authoritative dungeon-map-local aim position.
- Left-stick or D-pad input moves that aim continuously; it does not drive the physical OS mouse.
- While left-stick scan movement is active, the camera follows the aim and keeps its projected cursor centered.
- Right-stick input may detach and pan the camera without changing the aim or selected hex.
- Resuming left-stick input takes priority, smoothly returns the camera to the aim, and then restores the centered lock.
- `DungeonScanController.pointer_position` and `NavigationCursor` are screen-space projections of the world aim, not independent selection authority.
- The physical OS mouse remains independent.
- The map node under the world aim is resolved with a global-world physics query.
- The scan reticle is a dungeon-map-local selection indicator and follows the resolved map node.
- Camera panning changes only the aim's screen projection; it never rewrites the stored world aim.

For keyboard-and-mouse input, the viewport mouse position becomes the scan pointer only through the established input-mode handoff. Do not infer world selection from a stale cursor or move the OS mouse to imitate controller input.

## Godot transform cautions

- Do not apply a canvas transform to a position unless both the source space and destination space are known.
- `get_canvas_transform()` can reflect viewport stretching, camera state, canvas ownership, and runtime window configuration differently from a headless test environment.
- Do not compare a global physics point directly with `camera.position`; inherited scene offsets create runaway camera feedback.
- Do not send a dungeon-map-local point to `World2D.intersect_point()`; it will miss map nodes when the live scene root is offset or scaled.
- Prefer one named conversion function at the boundary over scattered `Transform2D` multiplication.
- Keep UI focus, scan software-pointer presentation, world selection, and camera focus as separate state. Ordinary GUI focus never overlaps a software pointer.

## Verification

Positioning regressions should cover:

- Both supported acceptance outputs: native `1280x800` (expanded `1920x1200` logical canvas) and `1920x1080`.
- A narrower terminal regression output such as `1200x800` where relevant.
- Correct separation between the centered world safe rectangle and controls that intentionally use the full viewport.
- Nonidentity parent transforms matching the live `WorldLayer` and `DungeonMap` hierarchy.
- A nonzero camera position and at least one non-default zoom level.
- Screen center, viewport edge, and corner positions.
- Both conversion directions when both are used.
- Center-locked left-stick movement at partial and full analog magnitude.
- Right-stick camera detachment while the world aim and selected hex remain stationary.
- Smooth camera reattachment when left-stick movement resumes, without cursor or reticle warping.
- Manual controller acceptance for cursor alignment, world anchoring, recentering, and absence of warping.

Avoid relying only on the default headless viewport. A square test viewport with a centered camera can hide an origin or aspect-ratio error.
