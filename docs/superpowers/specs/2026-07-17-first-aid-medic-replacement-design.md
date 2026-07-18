# First Aid Medic Replacement Design

## Goal

Replace Immunize with First Aid as the Medic role's first starting action. Immunize is no longer part of the active Medic kit, but its action and condition resources remain available for possible reuse in a future perk.

## Authored Behavior

First Aid targets one ally and heals them for 75% of Sands's PSY, increased linearly by the target's missing HP percentage. The runtime formula is:

```text
heal = 0.75 × PSY × (1 + missing HP percentage)
```

This ranges from 75% PSY at full HP to approximately 150% PSY near zero HP. Its description must state both the base potency and missing-HP scaling.

Triage intentionally uses the same curve across the full team. The shared curve is part of Medic's identity: First Aid supplies repeatable single-target sustain, while Triage is the team-wide payoff for shifting into Medic. No additional Triage mechanic is part of this change.

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
- Confirm First Aid loads in Medic slot 1, retains 0.75 healing potency, and enables missing-HP scaling.
- Confirm its description communicates both the 75% PSY base and missing-HP increase.
- Run broader verification proportional to the authored-content change.
