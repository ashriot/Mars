# Enemy HUD Contrast and Damage Feedback

## Status

Approved on 2026-08-04.

## Scope

This focused correction builds on [Enemy HUD Legibility Correction](2026-08-03-enemy-hud-legibility-correction-design.md). It changes world-HUD contrast, type scale, intent alignment, HP presentation, and enemy damage popups. The 220-pixel HUD width, guard geometry and layering, formation transforms, health-feedback colors, targeting, and combat rules remain unchanged.

## Steam Deck readability floor

Battle UI is authored against the 1920-pixel reference canvas and scales to the native 1280-pixel Steam Deck width. Free-standing strategic enemy text must therefore use at least 24 logical pixels, approximately 16 physical pixels at Steam Deck width. Text constrained inside an icon may use 20 logical pixels when supported by strong contrast and the icon's shape.

Apply these authored sizes:

- inspected enemy name: 28 pixels;
- intent, defenses, exact HP, `VULNERABLE`, and `BREACHED`: 24 pixels;
- guard value inside the current shield: 20 pixels.

This floor applies to new battle-presentation work unless a later approved standard supersedes it.

## Contrast and hierarchy

All world-HUD labels use opaque black outlines matching the existing battle UI's proportional treatment:

- 28-pixel text uses an 8-pixel outline;
- 24-pixel text uses a 6-pixel outline;
- 20-pixel icon-contained text uses a 4-pixel outline.

Intent is horizontally centered and receives a row tall enough to render 24-pixel type without clipping. Inspection remains above intent, followed by HP, guard or status, and conditions.

## HP presentation

The HP bar remains 220 pixels wide and becomes 32 pixels tall. It permanently centers `current / max` HP in 24-pixel outlined text inside the bar. Exact HP is no longer dependent on pointer hover, preserving controller parity; the existing tooltip may remain as secondary convenience.

Yellow delayed damage and green healing feedback remain behind the authoritative pink bar. The HP label updates from authoritative combatant state whenever HP changes and remains above both progress layers.

Guard pips remain in front of and overlap the lower HP edge. Their existing horizontal gap, ten-column layering, vertical layer step, and value semantics remain unchanged; only the guard/status typography and required vertical placement adapt to the thicker HP bar.

## Enemy damage popups

The missing popup is a presentation migration gap: the old actor card spawned `DamagePopup`, while the new enemy world presentation only updates health and plays Hit.

On `damage_received`, each living enemy world HUD spawns the established `DamagePopup` in the enemy HUD canvas at the projected center of that enemy's 3D model. Reuse the existing kinetic, energy, and piercing colors, critical `!`, outline, timing, and self-cleanup. Rapid hits retain deterministic separation so values do not occupy the same position.

The popup reports the same resolved damage value and critical state used by actor-card presentation. It does not alter HP, damage resolution, target legality, hit animation, health synchronization, or battle sequencing. If valid projected model bounds are unavailable, use the projected head/foot midpoint; if neither projection is valid, omit the cosmetic popup without blocking combat.

## Ownership

`EnemyWorldHUD` owns world-label styling, HP text, projected model-center placement, and popup spawning because it already receives authoritative presentation events and current projection bounds. `DamagePopup` remains the shared animation component. `EnemyDronePresentation` continues to own model animation and the presentation-operation boundary.

## Verification

Automated coverage protects:

- minimum font sizes and proportional black outlines;
- centered intent without clipping;
- 220-by-32 HP geometry and always-visible `current / max` text;
- HP text updates after damage and healing;
- guard-over-HP draw order and unchanged guard spacing/layers;
- one correctly configured popup on real `damage_received`, positioned at projected model center;
- critical and damage-type payload forwarding;
- rapid-hit separation and cosmetic omission without valid projection;
- W/M HUD containment and nonintersection at supported canvases and camera yaw limits.

Manual acceptance at `1920x1080` and native `1280x800` confirms that world text remains readable across bright walls and dark room regions, HP values are legible inside the bars, intent is centered, hover details remain attributable, damage values appear over the struck model, and repeated or critical hits remain distinguishable.
