# Endgame Battle Lab Checklist

The endgame battle lab runs the production battle scene with a fully developed
three-hero party while remaining outside the campaign and reward flow. The current
`Attack Drone + Defense Drone` encounter is a temporary systems smoke test. It is
not the final endgame benchmark party.

## Launch and presets

1. Use Godot `4.6.3` and open
   `res://src/dev/endgame_battle_lab.tscn`.
2. Select the `EndgameBattleLab` root node and review its exported properties in
   the Inspector.
3. Leave `Auto Start` enabled and run the current scene directly (`F6`). Do not
   launch it through `GameManager` or a campaign slot.
4. Confirm every enemy card is labeled `Rk. 10`, the default encounter seed is
   `4242`, and the fight begins with Asher, Echo, and Sands.

The `Equipment Preset` export supports:

- `SKILLS_ONLY` — all three roles and every nonstructural progression node are
  owned for each hero; duplicated equipment retains its authored tier and rank.
- `MAX_EQUIPMENT` — the same complete nine-role skill setup with duplicated current
  weapons and armor at tier 5, rank 30. It adds no invented mods or proficiency
  allocations.

Both presets clear injuries and temporary boons. The lab disables battle victory XP
and does not create, load, mutate, or save a campaign slot.

## Seed comparison

Use the exported `Encounter Seed` property to replay or vary a fight:

- [ ] Run seed `4242` twice with `MAX_EQUIPMENT`; confirm the opening CT head starts,
  critical rolls, random-hit targets, and enemy opening choices replay exactly.
- [ ] Change to a different non-negative seed; confirm at least one seeded outcome
  can differ while the party, Rank 10 override, and encounter composition stay fixed.
- [ ] Return to seed `4242`; confirm the original sequence returns.
- [ ] Repeat one seed with `SKILLS_ONLY` to isolate the effect of equipment scaling.

## Combat-system observation pass

The current drone encounter can establish that the lab launches, scales enemies,
and supports complete hero kits. Leave checks requiring the proposed benchmark
enemy skills unchecked until those skills and their encounter are approved and
implemented.

- [ ] Shift each hero through all three roles and use every legal Shift action.
- [ ] Use every hero action at least once, including buffs, debuffs, healing,
  targeting changes, multi-hit actions, and resource-scaled damage.
- [ ] Confirm action previews and visible enemy intents agree with executed damage.
- [ ] Confirm buffs and debuffs expire or are removed from the intended actor only.
- [ ] Confirm a post-shift debuff reacts only after the new role's Shift action.
- [ ] Confirm target-Focus and target-Guard scaling uses the exact target snapshot.
- [ ] Confirm enemy healing affects a living enemy without hero Focus scaling and
  does not revive a defeated enemy unless explicitly authored to revive.
- [ ] Observe whether one repeatable hero sequence dominates regardless of enemy
  state, target order, or role-shift timing.
- [ ] Note any intent whose target, damage, trigger reason, or secondary effect is
  unclear before committing a hero action.
- [ ] After victory or defeat, confirm no campaign XP, Bits, inventory, roster, run
  state, or save-slot bytes changed.

## Results log

Manually tally turns and events; the lab does not add benchmark-only telemetry to
the production battle runtime. Add rows as needed and keep each run unchecked until
its observations are recorded.

| Complete | Seed | Preset | Victory | Total turns | Defeats / revivals | Role shifts | Kill / Breach order | Cleanses | Enemy healing | Unused abilities | Dominant strategy | Unclear intents | Notes / commit |
| --- | ---: | --- | --- | ---: | --- | ---: | --- | --- | --- | --- | --- | --- | --- |
| [ ] | 4242 | `MAX_EQUIPMENT` |  |  |  |  |  |  |  |  |  |  |  |
| [ ] | 4242 | `MAX_EQUIPMENT` replay |  |  |  |  |  |  |  |  |  |  |  |
| [ ] |  | `MAX_EQUIPMENT` alternate seed |  |  |  |  |  |  |  |  |  |  |  |
| [ ] | 4242 | `SKILLS_ONLY` |  |  |  |  |  |  |  |  |  |  |  |

## Content gate

- [ ] Review and approve the Officer, Psyker, Gang Enforcer, and Defense Drone
  action names, coefficients, cooldowns, trigger conditions, target selectors,
  buffs, and debuffs.
- [ ] Approve the final two-enemy and four-enemy benchmark compositions.
- [ ] Replace the temporary drone encounter only through a separately approved
  benchmark-content implementation plan.

Do not treat this checklist as approval to create those enemy action, actor, or
encounter resources.
