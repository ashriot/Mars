# Battle World Lighting and Framing Design

## Status

Approved on 2026-08-02. This is a focused presentation correction for the first [local 3D battle slice](2026-08-02-local-3d-battle-slice-design.md).

## Problem

The first asset-backed playtest shows the EyeDrones staged too close to the hero-card band and the industrial room rendering almost black. Enemy HUDs remain readable, but the models are visually disconnected from them and the center of the battlefield reads as an empty void rather than a room.

## Desired Result

For this prototype phase, favor a clearly lit industrial combat arena over a heavily shadowed presentation. Enemy silhouettes, materials, and their relationship to the projected HUD must be immediately readable while the room retains dark metal surfaces and blue sci-fi accents.

## Composition

Raise the shared `EnemyViews` layer by exactly `1.0` world unit, approximately one EyeDrone radius. Keep the existing W/M horizontal and depth coordinates, camera origin, field of view, projection behavior, and gameplay semantics unchanged. Raising the common parent keeps ordinary enemies and future reserved boss positions in one consistent world-height system without embedding presentation height into formation policy.

The models and their head, foot, and bounds anchors move together. Their screen-space HUDs therefore follow automatically and remain associated with the correct model.

## Lighting

Lighting remains authored in tracked battle-world and room scenes so it behaves identically with local Quaternius models and tracked fallback geometry.

- Lift the near-black world background to a dark blue-gray so uncovered room areas no longer appear as pure void.
- Increase neutral ambient illumination to at least three times the current effective contribution, enough to reveal dark metal across the battlefield.
- Use a broad neutral front/top fill as the primary readability light.
- Retain cooler directional and practical lights as industrial accents rather than the only meaningful illumination.
- Do not edit ignored Quaternius resources or depend on vendor material changes.

The bright 2D hero UI remains unchanged. Exposure and light energy should be raised conservatively enough to avoid flattening the room or washing out emissive strips.

## Scope

This correction does not change combat rules, formation capacity, target navigation, enemy HUD content, camera motion, imported asset selection, hero UI, or controller behavior. It does not attempt final cinematic lighting; later environments may intentionally use moodier encounter-specific setups once the baseline presentation is readable.

## Verification

Automated checks protect the stable composition and scene contract:

- the shared enemy layer has the approved vertical offset;
- W/M transforms preserve their existing local coordinates;
- the battle environment provides non-black background and meaningful ambient illumination;
- the room retains broad key/fill lighting independent of optional local models.

Manual acceptance remains authoritative for visual quality. At `1920x1080` and `1280x800`, confirm that all active drones sit above the hero-card band, their projected HUDs remain clearly associated, dark model surfaces are visible, the central room reads as physical space, and the existing 2D interface remains legible.
