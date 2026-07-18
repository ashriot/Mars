# First Aid Medic Replacement Design

## Goal

Replace Immunize with First Aid as the Medic role's first starting action. Immunize is no longer part of the active Medic kit, but its action and condition resources remain available for possible reuse in a future perk.

## Authored Behavior

First Aid targets one ally and heals them for 75% of Sands's PSY. Its description must match that runtime potency.

## Active Content References

- Medic action slot 1 references `first_aid.tres` in both the role resource and progression definition.
- Progression-content expectations identify First Aid as the Medic root action.
- The active starting-role-kit checklist names First Aid instead of Immunize.
- Historical specifications and implementation plans remain unchanged as historical records.

## Dormant Immunize Content

The existing Immunize action and condition resources are retained without active Medic-kit references. This change does not redesign Immunize or convert it into a perk.

## Verification

- Import and parse the project with Godot 4.6.3.
- Run focused progression-content coverage.
- Confirm First Aid loads in Medic slot 1 and its displayed formula agrees with its 0.75 healing potency.
- Run broader verification proportional to the authored-content change.
