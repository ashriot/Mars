# Enemy World HUD Alignment

## Goal

Keep each enemy HUD visually attached to its 3D model, make detail reveals predictable, and keep imported enemy idle motion continuous. The result should remain readable with up to five enemies in either W or M formation without creating an artificial staircase of floating UI.

## Compact HUD

- Reduce the enemy HUD width from 220 pixels to 160 pixels.
- Reduce the HP bar from 168 pixels to 108 pixels while retaining the guard icon and value to its left.
- Keep the existing vertical information order: intent, guard and HP, then condition icons.
- Use a slightly smaller intent font where necessary so ordinary intent text fits the compact width; the existing tooltip remains the complete description.
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
- fixed downward detail placement without layout reflow;
- safe-area clamping;
- target hit regions remaining based on projected model bounds;
- only the inspected enemy revealing details;
- Idle being configured to loop while one-shot clips remain unchanged.

Manual acceptance should cover W and M formations with four and five enemies at `1920x1080` and `1280x800`, including pointer hover, controller target movement, group targeting, long intent text, and continuous idle motion.
