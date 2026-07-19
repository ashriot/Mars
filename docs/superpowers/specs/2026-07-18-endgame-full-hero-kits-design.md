# Endgame Full Hero Kits Design

## Goal

Make the endgame battle lab's benchmark party match the intended meaning of
"all skills unlocked": all three heroes own all three roles, every progression
node contributes its stats, and every action, passive, and Shift action authored
on each role definition is available in combat. The default benchmark party also
uses deep-duplicated tier-5, rank-30 weapons and armor.

## Current Problem

`EndgamePartyFactory` owns every nonstructural progression node and then asks
`ProgressionRebuilder` to derive each `RoleData`. The rebuilder correctly treats
the JSON progression catalog as authoritative, but several older progression
trees do not expose the complete kits still authored on their `RoleDefinition`
resources. For example, Psion's role definition contains Mind Storm, Psionic
Pulse, and Shatter, while `data/progression/echo/psi.json` contains none of those
rewards. Owning every existing JSON node therefore does not mean owning every
authored skill.

The factory tests currently protect node ownership but do not compare the
resulting battle kits with the authored role definitions.

## Design

The factory will continue to use `ProgressionRebuilder` first. This preserves
the production calculation of equipment stats, all owned stat nodes, and every
ability already present in JSON.

After a successful rebuild, the factory will apply a benchmark-only full-kit
overlay to each rebuilt role:

- A non-empty `RoleDefinition.actions` array replaces the rebuilt regular-action
  array in its authored slot order.
- A non-null authored passive replaces the rebuilt passive.
- A non-null authored Shift action replaces the rebuilt Shift action.
- Empty or null definition fields preserve the progression-derived value. This
  is required for Operative, whose current role definition has no kit resources
  while its JSON tree supplies Coordinate and Decoy.
- A missing rebuilt role for an unlocked definition is a transactional factory
  failure; the factory returns no partial roster.

This overlay is confined to `EndgamePartyFactory`. Ordinary campaign progression
continues to use the JSON catalog unchanged. Adding the missing skills to campaign
rank trees remains a separate content-design task because it requires rank,
prerequisite, and XP-cost decisions.

## Equipment

The existing presets remain distinct:

- `MAX_EQUIPMENT`, which is the lab scene's default, deep-duplicates every weapon
  and armor resource and sets tier 5, rank 30, and current XP 0.
- `SKILLS_ONLY` uses the complete benchmark kits but preserves the authored
  equipment tier/rank on deep duplicates.

No authored hero, role, action, weapon, or armor resource may be mutated.

## Tests

Focused factory coverage will establish:

- Every rebuilt role with authored regular actions has the exact authored action
  list and slot order.
- Every authored passive and Shift action is present.
- JSON-derived actions survive when the corresponding role-definition field is
  empty, protecting Operative.
- Psion explicitly contains Mind Storm as a regression check.
- Every max-equipment hero has tier-5, rank-30 weapon and armor duplicates while
  the authored equipment remains unchanged.
- The default lab scene continues to use `MAX_EQUIPMENT` and exposes tier-5,
  rank-30 weapon and armor on all three heroes.

Verification will include a clean Godot 4.6.3 import, focused party-factory and
battle-lab suites, the full isolated suite, direct lab launch through the first
player action, and `git diff --check`.

## Acceptance Criteria

- Mind Storm and every other authored role-definition skill are available in the
  benchmark party.
- All nine roles remain unlocked and retain all progression-derived stat rewards.
- Operative retains Coordinate and Decoy.
- The default lab party's three weapons and three armor pieces are all tier 5 and
  rank 30.
- Authored resources and campaign/save state remain unchanged.
- Campaign progression JSON is not modified by this change.
