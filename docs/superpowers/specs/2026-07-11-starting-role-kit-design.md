# Starting Role Kit and Tree Header Design

## Purpose

Make every unlocked role begin with its first two normal skills while keeping the first paid progression node at rank 2 and 200 XP. The top of each tree should communicate the role's baseline combat kit rather than consume two progression ranks.

Save compatibility, refunds, and reconciliation of existing prototype saves are explicitly out of scope. This design applies to fresh/default progression state only.

## Tree Header Layout

Every role tree begins with one visual row:

```text
[Starting Skill 1] — [ROLE NAME] — [Starting Skill 2]
                              |
                       [First Paid Node]
```

- The role name is a structural `role_anchor`, centered at column 0.
- Starting Skill 1 is positioned to the left of the anchor.
- Starting Skill 2 is positioned to the right of the anchor.
- Both skills are rank 1, cost 0 XP, and are automatically owned.
- The first paid stat or skill node is rank 2, centered beneath the anchor.
- Horizontal connectors associate both starting skills with the role; the vertical connector begins paid progression.
- Unlocking the role remains hero progression behavior. The anchor does not unlock or purchase the role.

## Starting Skills

| Hero | Role | Starting Skill 1 | Starting Skill 2 |
|---|---|---|---|
| Asher | Gunner (`gun`) | Double Tap | Fusion Ammo |
| Asher | Operator (`opr`) | Coordinate | Decoy |
| Asher | Sniper (`snp`) | Mark Target | Aimed Shot |
| Echo | Dominator (`dom`) | Displace | Feedback |
| Echo | Kinetic (`kin`) | Telekinesis | Rejuvenate |
| Echo | Psion (`psi`) | Focused Bolt | Energy Barrier |
| Sands | Medic (`med`) | Immunize | Booster Shots |
| Sands | Strategist (`stg`) | Tempo | Gambit |
| Sands | Vanguard (`van`) | Draw Fire | Overwatch |

## JSON and Runtime Model

Progression JSON gains explicit node semantics rather than inferring behavior from rank or position.

The structural anchor uses:

```json
{
  "id": "gun.anchor",
  "node_kind": "role_anchor",
  "rank": 1,
  "column": 0,
  "parent": null
}
```

Starting skill nodes use normal action effects plus explicit ownership:

```json
{
  "id": "gun.root",
  "node_kind": "progression",
  "starting_owned": true,
  "rank": 1,
  "column": -1,
  "parent": "gun.anchor",
  "xp_cost": 0,
  "effect": {
    "type": "action",
    "resource": "res://data/heroes/asher/actions/double_tap.tres",
    "slot": 1
  }
}
```

The second starting skill mirrors this at column 1. Ordinary nodes default to `node_kind: "progression"` and `starting_owned: false` when omitted.

The loader and definitions enforce:

- Exactly one `role_anchor` per role.
- The anchor is the only parentless node.
- Anchors have no effect, purchase cost, ownership, or refund value.
- Exactly two `starting_owned` action nodes exist per production role.
- Starting nodes have rank 1, cost 0, distinct action slots, and the anchor as parent.
- Starting-owned nodes cannot be purchased.
- Paid progression may treat the structural anchor as an automatically satisfied prerequisite.

## Fresh Progression Initialization

When a fresh hero receives an unlocked role, or a role is newly unlocked during progression, the progression system creates that role's `HeroRoleProgress` with both starting node IDs already owned.

Starting nodes are recorded with 0 XP paid. Purchase code continues to record actual prices for paid nodes. A future refund system will therefore refund only purchased progression.

No load-time migration or repair of existing prototype saves is added. Existing saves may be discarded during this development stage.

## Rank and Price Reflow

Moving the former second skill into the header removes it from the paid path.

- Existing nodes above the removed skill retain their ranks.
- Nodes below the removed skill move up one rank to close the progression gap.
- Sands roles already place their second skill at rank 2; their former rank-3-and-later nodes move up one rank.
- Prices are recalculated from the new rank using the existing pricing pattern: standard nodes use `rank * 100`, while enhanced branch nodes preserve their current premium multiplier.
- The first paid node is rank 2 and normally costs 200 XP.
- Current mature trees may end at rank 9 after reflow. The missing rank-10 stat boost or capstone is intentionally deferred as future balance content.

For the two incomplete trees, the first paid rank-2 node is explicitly a broad stat increase: Operator receives `HP +5`, and Dominator receives `PSY +1`. First paid nodes should use broadly useful `HP`, `ATK`, or `PSY` effects rather than specialized stats such as `PRE`.

The reflow preserves node IDs and relative branch relationships. Only the former second skill's position/parent and affected rank/cost values change.

## Presentation and Interaction

- The role anchor uses a dedicated non-purchasable visual distinct from owned and locked nodes.
- Starting skills render as owned immediately.
- Focusing the anchor shows role identity/description but no purchase action or XP price.
- Focusing a starting skill shows its action details but no purchase/refund prompt.
- Mouse and controller navigation may focus all three header items.
- Directional navigation from the anchor moves left/right to starting skills and down to the first paid node.
- Directional navigation from either starting skill moves inward to the anchor and down toward paid progression where geometrically appropriate.

## Testing

Automated tests cover:

- Schema acceptance and rejection for anchors and starting-owned nodes.
- All nine production roles having the exact approved two-skill starting kit.
- Fresh role progress owning both starting skills with zero XP paid.
- Starting skills applying to rebuilt battle roles without reducing hero XP.
- Anchors and starting skills rejecting purchase attempts.
- First paid nodes beginning at rank 2 with the intended price.
- Rank/cost reflow preserving node IDs, valid parent graphs, and production content validity.
- Header rendering, geometric navigation, and absence of purchase hints on anchors/starting skills.
- Existing paid purchase, save, refresh, and rollback tests remaining green.

Manual verification confirms the header layout, connectors, role descriptions, both starting actions in combat, and controller/mouse navigation for every role.

## Deferred Content

Some trees will have an open rank-10 slot after reflow. New stat boosts or capstones for those slots are balance/content work and should be tracked for later rather than invented during this structural change.
