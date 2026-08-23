# Mobile Battle Lighting and HiDPI Design

## Purpose

Make the fixed industrial battle room read as a dimensional, enclosed combat space without abandoning the renderer and light budget required by Godot's Forward Mobile path. Preserve the existing responsive policy: Steam Deck's native 1280x800 output is the compact acceptance target, 1920x1080 is the desktop reference, and 4K full-screen output enlarges the same authored interface instead of making it physically smaller.

## Scope

This effort changes the battle-room lighting rig and protects the established canvas scaling policy with automated coverage. It does not introduce GI, light baking, reflection probes, a graphics-settings screen, saved display preferences, material replacement, or changes to combat layout and rules.

## Display Policy

The project keeps its existing 1920x1080 logical authoring reference and `canvas_items` / `expand` stretch policy.

- At 1280x800, the engine exposes the existing 1920x1200 logical canvas at two-thirds physical scale. The compact display profile owns the responsive adjustments required to keep controls readable.
- At 1920x1080, the logical and physical reference composition are one-to-one.
- At 3840x2160, the logical canvas remains 1920x1080 and the engine presents it at two times physical scale. The authored battle UI and world composition therefore remain the same apparent proportions and are not microscopic.
- At 16:10 and ultrawide aspect ratios, `expand` may expose additional logical space. The centered 1920x1080 safe composition remains the protected combat frame; responsive overlays may use the additional area only when their own layout permits it.

The desktop startup policy remains a 1920x1080 window. Full-screen selection and user-persisted resolution settings are separate work; when a player does use a 4K full-screen output, this policy already scales correctly.

## Lighting Approach

The room remains Mobile-compatible: one shadowed directional key, non-shadowed positional fills, one diffuse-only bounce, color-sourced ambient illumination, and emissive geometry for visible practical fixtures. No SDFGI, VoxelGI, lightmap baking, reflection probes, or volumetric effects are introduced.

The lighting should be tuned as a three-part composition rather than by globally raising exposure:

1. The shadowed neutral-cool directional key defines the wall panels, bulkhead, pillars, and floor. It provides the primary shape and shadow separation.
2. A tighter non-shadowed local fill near the party viewpoint restores readable detail on the near walls and drone faces without washing out the room.
3. A restrained colored rear accent around the bulkhead separates the enemy silhouettes from the back wall and gives the bay repetition depth. The existing diffuse-only bounce remains weak and cool so black metal retains shadow information without becoming a broad front wash.

Ambient energy is reduced enough that the key and accent lights remain visible in the final image. Actual numeric values are tuned only through windowed framebuffer probes at the three acceptance outputs below; the chosen values must stay within the Mobile light budget.

## Acceptance

Automated coverage protects these contracts:

- 1280x800 remains compact and all existing layout acceptance tests continue to pass;
- 1920x1080 remains the reference canvas;
- 3840x2160 produces a 2.0 output scale and a 1920x1080 logical canvas;
- the room retains exactly one shadowed key, non-shadowed local fill/accent lights, and a diffuse-only non-shadowed bounce.

Windowed framebuffer probes are authoritative for visual approval at 1280x800, 1920x1080, and 3840x2160:

- hero cards and actions remain readable and retain their relative composition;
- dark metal, pillars, drones, and bulkhead have distinct light and shadow values;
- the bulkhead and bay rhythm have visible depth behind the enemy formation;
- the lighting does not wash out the UI, crush the room into black, or reveal clear-color gaps.

## Out of Scope

- Global illumination, baking, reflection probes, fog, and post-process overhaul.
- 3D material/asset replacement or room geometry redesign.
- Player-selectable graphics modes and full-screen/resolution persistence.
- Changes to the approved hero-row or HUD canvas layering fixes.
