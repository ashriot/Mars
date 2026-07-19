# Starting Role Kits Manual Checklist

Use a fresh prototype campaign. Prototype saves from before starting-role-kit progression may be discarded; save migration is intentionally not tested or supported by this checklist.

## Setup

- [ ] Start a new campaign from the title screen and enter the hub.
- [ ] Record each hero's XP before opening the skill tree.
- [ ] For the complete nine-role pass, use the normal prototype/debug unlock path to expose Operative and Telepath in addition to the seven roles unlocked by a fresh campaign. Do not reuse an old save to unlock them.
- [ ] Repeat navigation checks once with mouse/keyboard input and once with a controller.

## Header and starting-kit matrix

For every row, confirm the centered role header, the left and right starting-skill labels, and the connector from the header to each starting skill. Both starting skills must use the owned visual style, omit a price, and be selectable for inspection without offering or completing a purchase.

| Hero | Role ID | Header | Left starting skill (slot 1) | Right starting skill (slot 2) |
| --- | --- | --- | --- | --- |
| Asher | `gun` | Gunner | Double Tap | Fusion Ammo |
| Asher | `snp` | Sniper | Mark Target | Aimed Shot |
| Asher | `opr` | Operative | Coordinate | Decoy |
| Echo | `psi` | Psion | Focused Bolt | Energy Barrier |
| Echo | `kin` | Kineticist | Telekinesis | Reconstruct |
| Echo | `dom` | Telepath | Displace | Feedback |
| Sands | `van` | Vanguard | Draw Fire | Overwatch |
| Sands | `med` | Medic | First Aid | Covering Fire |
| Sands | `stg` | Strategist | Tempo | Gambit |

- [ ] All nine headers and role names match the matrix.
- [ ] All eighteen left/right skill labels match the matrix.
- [ ] Each header has visible left, right, and downward connectors, with no broken or stray connector lines.
- [ ] Each starting skill has the owned style and shows no XP price.
- [ ] The first node below every header is rank 2, displays a price of 200 XP, and is not owned in a fresh campaign.
- [ ] Later/final ranks intentionally remain open-ended where content stops; confirm the UI does not draw a false cap, placeholder reward, or connector to nowhere.

## Purchase safety and navigation

- [ ] With the role header focused, controller Left reaches the slot-1 skill, Right returns through the header and reaches the slot-2 skill, and Down reaches the paid rank-2 node.
- [ ] Controller Confirm on the header does not buy anything.
- [ ] Controller Confirm on either starting skill does not buy anything.
- [ ] Mouse-clicking the header or either starting skill does not buy anything.
- [ ] After every header/starting-skill interaction, the hero's XP is unchanged from the recorded value.
- [ ] Give the hero exactly 200 available XP, activate the rank-2 node with controller Confirm, and verify the existing purchase flow fires once, deducts exactly 200 XP, and changes the node to the owned style.
- [ ] Repeat the paid-node interaction with the mouse and verify the same price, ownership, and single-purchase behavior.

## Combat action exposure

- [ ] Enter combat with each role active and verify the matrix's left skill appears in action slot 1 and right skill appears in action slot 2.
- [ ] Activate slots 1 and 2 with controller action bindings and with mouse clicks; verify the displayed action and targeting behavior match the selected skill.
- [ ] Operative specifically exposes Coordinate in slot 1 and Decoy in slot 2, and both can be selected in combat.
- [ ] Telepath specifically exposes Displace in slot 1 and Feedback in slot 2, and both can be selected in combat.
- [ ] Returning to the hub preserves owned starting styling and does not charge XP for either starting action.

## Save boundary

- [ ] Perform this pass on a newly created prototype save.
- [ ] Do not test migration of saves created before starting-role-kit progression. Those prototype saves may be discarded, and no node-ID mapping or migration guarantee is part of this feature.
