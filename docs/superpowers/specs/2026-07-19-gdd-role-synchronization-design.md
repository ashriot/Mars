# GDD Role Synchronization Design

## Purpose

Synchronize the nine currently authored hero Roles with the authoritative Google Doc. The finished game data must match the document for Role names, descriptions, normal actions, Shift actions, and passive traits. Supporting conditions, triggers, targeting, costs, formulas, damage types, and durations are part of the behavior and must match as well.

This work restores a trustworthy relationship between design documentation and runtime content. It is not a general balance pass or a redesign of the heroes.

## Authority and Interpretation

The current Red Shift GDD is authoritative for the scoped behavior. When code, resource descriptions, progression data, tests, and the GDD disagree, the GDD wins unless the user explicitly resolves an ambiguity differently.

Resolved interpretation decisions:

- Echo's psychic controller Role is **Telepath**. The code name **Dominator** is obsolete.
- Role passives and Shift actions are included in the synchronization. They are core Role behavior, not deferred progression content.
- Ordinary healing cannot revive a defeated hero during combat. Reaching 0 HP removes that hero from combat until the existing post-combat revival flow.
- Role perks, character perks, and perk selection are deferred. Effects that duplicate a documented perk but are currently baked into a base action or passive must be removed from the base behavior.
- No save migration or backward-compatibility work is required for this pre-alpha content change.

## Scope

The implementation covers Asher's Gunner, Sniper, and Operative; Echo's Psion, Kineticist, and Telepath; and Sands's Vanguard, Medic, and Strategist.

For each Role, synchronize:

- Role name and description
- Four normal actions and their ordering
- Shift action
- Passive trait
- Focus and CT costs
- Targeting and auto-target behavior
- Damage and healing power sources, potencies, hit counts, and damage types
- Buff and debuff values, triggers, removal conditions, and caps
- Guard, Focus, CT, and Speed changes
- Tooltip text and dynamic effect presentation
- Progression references needed to expose the corrected actions
- Automated behavior coverage

## Content Synchronization

### Asher

#### Gunner

Preserve the documented Suppressive Fire, Bullet Time, Double Tap, and Bullet Storm behavior.

- Fusion Ammo uses 75% CT Cost and adds one 50% PSY Energy hit to Asher's attacks until he Shifts or is Breached. It does not also grant an undocumented outgoing-damage multiplier.
- Siphon Shots deals three 75% ATK Energy hits and heals Asher for half the damage dealt.

#### Sniper

Preserve Exploit Weakness and Targeting Laser.

- Charged Shot grants two Focus when the target is either Vulnerable or Breached.
- Mark Target uses 50% CT Cost.
- Aimed Shot deals 200% ATK Kinetic damage and gains the documented Aim bonus against Marked targets.
- Concussive Shot deals 550% ATK Kinetic damage and consumes Marked for the documented delay.

#### Operative

Complete the Role definition and progression exposure instead of leaving standalone orphan resources.

- Dismantle is the Shift action and removes half the target's Guard, rounded up, capped at five Guard removed.
- Teamwork is the passive and grants the team one Focus whenever any enemy becomes Breached.
- Coordinate grants a teammate a buff that refunds the full Focus cost of their next action.
- Decoy costs one Focus, grants one Guard, and makes the chosen team member untargetable until the start of that hero's next turn.
- Debilitate costs two Focus and reduces the target's next attack damage by 35%.
- Ensnare costs two Focus, deals 150% PSY Energy damage, and slows the target by 25% until it gains Guard.

The implementation must enforce Dismantle's cap in runtime behavior rather than only describing it in text.

### Echo

#### Psion

- Shatter deals 50% ATK Energy damage per point of Echo's current Guard, split across all enemies, then reduces her Guard to zero.
- Psionic Pulse deals 35% PSY Energy damage to every enemy at the start of Echo's turn.
- Focused Bolt deals 25% ATK Energy damage per point of Echo's Focus.
- Energy Barrier grants two Guard and retaliates against the next attacker for 150% PSY Energy damage.
- Reverberate costs three Focus, initially deals 200% ATK Energy damage, and makes the next Kinetic hit trigger 200% PSY Energy damage.
- Mind Storm starts at 500% ATK Energy damage and gains 20% damage per Focus remaining after its five-Focus cost is paid.

#### Kineticist

Retain the Kineticist name and its protective, healing, and Focus-support identity. Correct the runtime Role description accordingly.

- Force Field is the Shift action and grants the team one Guard.
- Acuity is the passive and grants Echo two Focus at the start of her turn.
- Telekinesis deals 75% ATK Kinetic damage and grants each of Echo's teammates one Focus.
- Reconstruct costs two Focus and heals for 50% PSY, increased by 50% for each point of Focus the target has.
- Pain Transfer costs two Focus, deals 200% PSY Kinetic damage, and applies the documented team-healing-on-hit effect at 50% PSY until Echo's next turn.
- Energize retains its documented four-Focus cost, 50% CT Cost, and four-Focus grant to a teammate.

The obsolete Rejuvenate, Kinetic Wall, and Telepathy names should not remain as player-facing Kineticist action names. Existing resource paths may be renamed only when doing so is cohesive and all references and required sidecars are updated; otherwise the resources may retain internal paths while exposing the authoritative names.

#### Telepath

Rename the code Role and player-facing references from Dominator to Telepath while retaining the stable `dom` Role ID unless a required implementation detail proves that the ID itself must change. Avoiding an unnecessary ID migration keeps the change focused.

- Suppress is the Shift action and reduces one enemy's damage by 25% until Echo Shifts.
- Precognition is the passive and grants the team one Guard at the start of Echo's turn.
- Displace grants Echo or a teammate one Guard and removes one debuff.
- Feedback makes the target lose one Guard and take 50% PSY Piercing damage for each hit in its next attack.
- Static Charge delays the target by 25%, slows it by 25% until its next turn, and deals 100% PSY Piercing damage at the start of that turn.
- Inversion deals 50% PSY Piercing damage per point of Guard the target attempts to gain, capped at ten points of Guard for damage calculation. Base Inversion does not prevent the Guard gain; prevention belongs to its deferred Nullification perk.

### Sands

#### Vanguard

Preserve Opening Salvo, Return Fire, and Overwatch.

- Draw Fire grants one Focus in addition to its documented taunt.
- Rename the code's Focus Fire action to the documented Crossfire name while preserving its 250% ATK Kinetic split damage and one-Focus reward for each Breached target hit.
- Phalanx costs four Focus and deals four 35% ATK Kinetic hits, granting one Guard to the lowest-Guard teammate for each hit against a Breached target.

#### Medic

- Triage heals the party from a 50% PSY base, increased separately for each target by that target's missing-HP percentage.
- Painkillers reduces party damage taken by 10%.
- First Aid is a fixed 75% PSY single-target heal without the deferred Critical Care missing-HP scaling.
- Rename Booster Shots to the documented Covering Fire name. It costs one Focus, deals two 50% ATK Kinetic hits, and doubles Painkillers until Sands Shifts.
- Auto-Shield costs two Focus, immediately grants one Guard and heals 50% PSY, then restores one Guard and heals 50% PSY at the start of the target's turns until that target Shifts.
- Bastion retains its documented four-Focus cost and three-Guard party effect.

#### Strategist

Preserve Opening Move, Tempo, and Gambit.

- Fianchetto grants 10% Speed and is removed cleanly from the party when Sands leaves Strategist.
- Advantage costs three Focus, boosts the teammate's next turn by 50%, and adds 100% of Sands's PSY to that hero's next attack, distributed proportionally across its hits and targets. It is not a generic 50% outgoing-damage multiplier.
- Checkmate deals 300% PSY Energy damage and delays the target by 50%.

## Defeat and Healing Rules

Ordinary healing effects are non-reviving by default.

- Defeated heroes are invalid targets for single-target ordinary healing.
- Party healing skips defeated heroes.
- Healing-over-time, lifedrain, healing triggers, and conditional healing cannot revive a defeated hero.
- A future dedicated combat-revival mechanic may opt into revival explicitly through a clearly named and tested effect or property.
- Existing post-combat revival and Injury behavior remains unchanged.

The implementation should make non-revival the safe default in the healing effect API so new ordinary heals cannot accidentally revive by omission.

## Implementation Boundaries

Prefer data-resource changes when the runtime already expresses the documented behavior. Add or refine effect/condition code only for behavior that the current data model cannot represent safely, such as a capped proportional Guard change, Teamwork's Breach event, proportional attack bonus distribution, or explicit non-reviving target rules.

Keep new runtime primitives reusable and narrowly named after their behavior rather than a single action. Avoid embedding hero- or action-name checks in general combat systems.

Progression definitions should continue to control action acquisition. Role definitions provide the authoritative Shift action and passive and may provide complete mature action arrays where that is the established pattern. Operative and Telepath must expose their full intended kit in endgame/full-kit construction after synchronization.

## Bug Handling During Implementation

Newly observed buggy behavior must be recorded and reported to the user with reproduction evidence.

- Fix it in the synchronization change when it directly prevents a scoped documented behavior, corrupts a touched Role's state, or is a local defect in a file already required by this work.
- Add regression coverage for every such in-scope fix.
- Do not silently expand into unrelated combat, UI, progression, save, or content refactors.
- For an unrelated or architecturally broader defect, stop changing that area, document the observation and likely impact, and ask the user before expanding scope.

Known audit findings to verify include Fianchetto Shift cleanup, Inversion carrying an unused Guard-removal flag, Fusion Ammo applying an undocumented damage modifier, action tooltips disagreeing with their effect resources, incomplete Operative/Telepath Shift-passive wiring, and ordinary heals defaulting to revival. Preserve any correct overlapping user changes already present in the working tree rather than reimplementing or overwriting them.

## Testing and Verification

Use behavior-boundary tests rather than checking resource text alone.

Each Role receives focused coverage for:

- Correct action, Shift, and passive wiring
- Focus and CT costs
- Power stat, potency, damage type, and hit count
- Target selection and group distribution
- Guard, Focus, CT, healing, and Speed changes
- Buff/debuff application, trigger timing, caps, consumption, and Shift cleanup
- Passive activation on entry and removal on exit
- Documented interactions such as Marked, Painkillers, Return Fire, Breach, Vulnerable, and Guard gain

Healing coverage must prove that ordinary single-target, party, triggered, and recurring heals do not revive defeated heroes while still healing valid living targets.

Run focused tests while implementing each Role, then run the complete automated suite because the work spans combat effects, progression rebuilding, hero kits, Role Shifting, and target eligibility. Parser errors, crashes, and unexpected runtime errors are failures even if assertions otherwise pass.

Manual verification should cover action-bar presentation, dynamic tooltip accuracy, Role names, Shift/passive indicators, and one representative combat loop for each hero. Pure numeric and state-transition behavior should remain automated.

## Non-Goals

- Implementing Role or character perks
- Rebalancing documented values based on the current code
- Introducing shared FFXIII-style classes
- Changing the Godot version or vendored plugins
- Save migration or compatibility with existing prototype saves
- Broad combat architecture refactoring unrelated to the documented behavior
- Adding a combat-revival action

## Acceptance Criteria

The synchronization is complete when all nine Roles expose the documented base kit, Shift action, and passive; player-facing names and descriptions match the authoritative design; runtime mechanics and tooltips agree; ordinary healing cannot revive defeated heroes; focused and full automated verification pass; and any newly discovered out-of-scope bugs are reported rather than silently absorbed.
