# Industrial Battle Room Rebuild Design

## Status

Approved on 2026-08-02. This replaces the barren model-test arrangement created for the first local 3D battle slice with a composed mechanical combat chamber.

## Problem

The current `IndustrialRoom3D` is a floor slab, one back wall, and a handful of isolated props. A persistent fallback backdrop added during lighting diagnosis reads as a featureless rectangle, while a mis-scaled imported column clips through the frame. Because the scene has no side walls, ceiling, repeated structure, or layered focal point, increasing light energy only makes an incomplete room more obvious.

## Desired Result

Build a compact, fixed-camera sci-fi shoebox that reads immediately as a mechanical room at both supported battle resolutions. It should use repetition, symmetry, and depth from the Quaternius Modular Sci-Fi MegaKit without reproducing the example laboratory scene. The central combat volume must remain visually quiet enough for up to five enemies and their projected HUDs.

## Composition

The room is three shallow structural bays deep, with the camera-facing side open:

- a real floor, back wall, left wall, right wall, and ceiling;
- three repeated frame lines running from the camera toward the back wall;
- paired vertical supports at each frame line;
- ceiling and side-wall light strips repeated with the structure;
- a layered back wall centered on a sealed illuminated mechanical bulkhead;
- vents, cables, panels, and small machinery concentrated around the room edges;
- an uncluttered central enemy stage with clear silhouette separation.

The shell should feel wider than it is deep. It is presentation scenery, not a navigable level, so unseen exterior faces and complete physical architecture are unnecessary.

## Modular Asset Assembly

Continue using `OptionalLocalModel3D` wrappers so ignored local Quaternius models can replace tracked fallback geometry without becoming repository dependencies. Repeated architecture may reuse the same local resource path, but each visible bay receives an authored transform appropriate to its role.

Imported models must be inspected at their native orientation and approximate dimensions before transforms are authored. Do not compensate for unknown bounds with extreme scaling. Side walls, ceiling pieces, and structural columns must face into the room and remain outside the camera and enemy volumes.

Tracked fallback meshes should preserve the same overall shell and silhouette when local assets are unavailable. They may be simpler, but must not collapse back into a single wall-and-floor test stage.

Remove `BattleBackdrop`; the assembled back wall is responsible for closing the room visually.

## Lighting

Keep the Mobile-compatible hierarchy established in the preceding lighting work: one shadowed key, one local non-shadowed fill, a subtle diffuse-only bounce, and color-sourced ambient illumination. Re-aim or reposition those lights only after the room shell is assembled.

Lighting should reveal structural repetition and separate enemies from the back wall. Emissive practical strips provide depth cues but do not replace actual illumination. Avoid broad front washes and extreme exposure changes.

## Battle Presentation Constraints

Do not change the battle camera, five-enemy W/M formation transforms, enemy model elevation, projected enemy HUD contract, hero cards, action UI, controller behavior, or combat rules in this rebuild. Architecture and props must stay out of the active enemy silhouettes and the lower hero-card band.

The room must support the future boss reservation where a large boss occupies the central three formation slots with one ally on each side.

## Verification

Automated checks should protect stable scene contracts:

- `BattleBackdrop` is absent;
- the room contains authored left, right, back, floor, and ceiling structure;
- three structural bay lines are present;
- local-model wrappers continue to provide tracked placeholders;
- the Mobile lighting hierarchy remains present;
- the battle camera, enemy elevation, and five formation transforms are unchanged.

Manual acceptance is authoritative for composition. At `1920x1080` and `1280x800`, confirm that the room reads as enclosed space, repeated bays create depth, no imported module clips through the frame, the bulkhead provides a clear focal point, enemies remain visually dominant, and the hero/action interface stays legible.

## Out of Scope

This rebuild does not add animation, particles, encounter-specific room variants, destructible scenery, navigation, collision, first-person projectiles, UI redesign, or final cinematic lighting.
