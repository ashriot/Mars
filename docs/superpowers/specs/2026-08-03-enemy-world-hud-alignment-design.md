# Enemy World HUD Alignment

## Goal

Keep each enemy HUD visually attached to its 3D model, make detail reveals predictable, and keep imported enemy idle motion continuous. The result should remain readable with up to five enemies in either W or M formation without creating an artificial staircase of floating UI.

## Compact HUD

- Reduce the enemy HUD width from 220 pixels to 160 pixels.
- Reduce the HP bar from 168 pixels to 108 pixels.
- Render HP with `ProgressBar` style boxes whose background and fill both have rounded corners, matching the established rounded health treatment on hero cards.
- Place guard shields beneath the HP bar with a slight overlap so they read as physically protecting HP.
- Display guard in ten fixed X columns and at most three vertical layers. Each additional layer uses the same X positions with a 5-pixel downward Y offset and no horizontal offset.
- Keep heroes capped at 10 guard and cap enemies at 30 guard.
- For guard 1–10, render the current layer white. For guard 11–20, render the completed first layer medium gray and the current second layer white. For guard 21–30, render the first layer dark gray, the second layer medium gray, and the current third layer white.
- Center the exact guard integer inside the newest shield in the current layer.
- At exactly zero guard, replace shields with `VULNERABLE` while `is_in_danger` is true and `BREACHED` while `is_breached` is true. These labels share the one-layer guard slot and may overlap the lower edge of HP slightly.
- Place conditions 5 pixels below the actual guard/status slot. `VULNERABLE`, `BREACHED`, and guard 1–10 use the same minimum slot height; conditions move down only 5 pixels at guard 11 and another 5 pixels at guard 21.
- Keep the vertical information order: intent, HP with overlapping guard/status, then condition icons.
- Use the current theme font resources so the user's Exo 2 replacements apply automatically; do not introduce a HUD-specific font override. Use a slightly smaller intent size where necessary so ordinary intent text fits the compact width, while the existing tooltip remains the complete description.
- Center each compact HUD directly over its projected head anchor.
- Clamp HUDs only to the viewport safe area. Do not move one enemy HUD vertically to avoid another HUD, because that breaks its visual attachment to the model.

## Detail Reveal

- Place the name and defense detail block at one fixed offset below the compact HUD, centered on the same model anchor.
- Never flip details above, beside, or into another dynamically selected location.
- Revealing details must not move any compact HUD or another enemy's details.
- Show details only for the enemy currently inspected by pointer hover or controller cursor. Merely highlighting all affected enemies for a group action must not expand every HUD.
- The detail block may overlap the upper edge of its owning model; that is preferable to detaching it from the model or covering another nameplate.

## Layout Ownership

`EnemyWorldHUD` owns the compact and expanded geometry relative to one projected head anchor. `BattleWorld3D` supplies the viewport safe rectangle but no longer resolves inter-enemy HUD or detail collisions. Target hit regions continue to use the projected 3D model bounds and therefore remain independent of the narrower visible HUD.

## Idle Animation

The imported Eye Drone `Idle` animation is 3.33 seconds long with looping disabled. `EnemyDronePresentation` will explicitly configure an available `Idle` clip to loop before playing it. Attack and Hit remain one-shot animations. Models without an animation player or Idle clip retain the current safe fallback behavior.

## Verification

Automated coverage will protect:

- compact dimensions and direct head-anchor placement;
- enemy guard clamping at 30 without changing the hero cap of 10;
- three-tier guard count, color, status-label, overlap, and condition-offset behavior;
- fixed downward detail placement without layout reflow;
- safe-area clamping;
- target hit regions remaining based on projected model bounds;
- only the inspected enemy revealing details;
- Idle being configured to loop while one-shot clips remain unchanged.

Manual acceptance should cover W and M formations with four and five enemies at `1920x1080` and `1280x800`, including pointer hover, controller target movement, group targeting, long intent text, and continuous idle motion.
