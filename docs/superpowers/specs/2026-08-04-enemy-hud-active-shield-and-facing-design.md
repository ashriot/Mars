# Enemy HUD Active Shield and Facing

## Status

Approved on 2026-08-04.

## Scope

This focused polish pass builds on [Enemy HUD Contrast and Damage Feedback](2026-08-04-enemy-hud-contrast-and-damage-feedback-design.md). It corrects malformed intent markup, gives long intents additional display width, emphasizes the current guard shield, and turns ordinary enemies toward the party. It does not change combat rules, guard values, formation positions, targeting, HP behavior, or the five-enemy limit.

## Intent presentation

Intent remains centered above the enemy identity and HP rows at the established 24-pixel Steam Deck readability floor. Its display lane may extend horizontally beyond the 220-pixel HP bar so ordinary phrases such as `Fortify Attack Drone` remain on one line without shrinking the type.

The wider intent lane is visual overhang, not a reason to widen every HUD row. Formation projection must reserve enough horizontal space to prevent neighboring intent labels from colliding at supported resolutions and camera yaw limits. Extremely long future boss intents may later use a condensed face, shorter authored wording, or icon-led presentation; this pass does not introduce a new font or intent vocabulary.

Intent formatting must emit balanced BBCode. Target-color spans close before outer alignment tags, so markup such as `[/center]` never appears as visible text.

## Guard hierarchy

The guard stack keeps its existing ten-column count language, horizontal gap, downward layer stacking, and layer-darkening rules. Ordinary shields remain compact so ten can fit beneath the 220-pixel HP bar.

The current, rightmost shield becomes a raised value badge:

- it is visibly larger than ordinary shields;
- it may overlap the shield immediately to its left and hang beyond the HP bar's right edge;
- it renders above neighboring shields and the HP bar;
- a strong black outline or drop shadow separates it from adjacent white shields and makes it appear closer to the viewer;
- its guard integer remains centered and fully contained at the established 20-pixel icon-text floor.

Only the current shield is enlarged. This preserves count readability while giving the exact guard value enough room. The same visual language may later be adopted by hero cards, but hero-card changes are outside this pass.

`VULNERABLE`, `BREACHED`, conditions, multi-layer guard values, and guard-zero behavior remain as previously approved.

## Enemy facing

Ordinary enemy positions retain the approved W/M formation. Their yaw turns toward a fixed party focal point near the nominal camera position instead of sharing an identity rotation. This makes outer enemies face slightly inward and prevents the wall-eyed appearance.

Facing uses yaw only. Enemies do not pitch toward the camera and do not continuously track subtle mouse-driven camera movement. A fixed focal point preserves the first-person diorama composition and avoids visible swiveling during ambient camera motion. Model-forward-axis calibration belongs in the presentation layer and must work for both front and back rows.

## Ownership

`EnemyIntentFormatter` owns balanced intent markup. `EnemyWorldHUD` and its scene own intent-lane geometry and text presentation. `EnemyGuardStack` and its scene own active-shield size, overlap, draw order, shadow, and value containment. `BattleFormationLayout` owns deterministic stage-facing yaw toward the party focal point; model-specific forward-axis correction remains local to enemy presentation if required.

## Verification

Automated coverage protects:

- balanced intent BBCode with no visible alignment tags;
- one-line presentation for the representative `Fortify Attack Drone` intent at the authored HUD scale;
- unchanged 220-pixel HP width and unchanged ordinary guard count/layer semantics;
- a larger active shield with readable contained value, controlled left overlap, right overhang, shadow, and top draw order;
- formation positions remaining unchanged while left and right enemies yaw inward toward the fixed focal point;
- stable yaw when the camera performs its ambient edge motion;
- W/M HUD containment and nonintersection at supported canvases.

Manual acceptance at `1920x1080` and native `1280x800` confirms that long ordinary intents do not wrap, guard count and value are both immediately readable, the active shield appears raised rather than merged into its neighbors, and every drone appears to address the party.
