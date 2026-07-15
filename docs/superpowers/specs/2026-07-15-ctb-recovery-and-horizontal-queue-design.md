# CTB Recovery and Horizontal Queue Design

## Purpose

Make combat turn order deterministic, keep the active combatant at the head of the projection, support signed CT debt and authored action recovery, and replace the temporary vertical text list with a horizontal portrait queue whose gauges communicate fixed tick distances.

The system remains based on Final Fantasy X's Conditional Turn-Based model: Speed controls how quickly an actor reaches a turn, actions and effects can move later turns, and the UI previews the resulting order before an action is confirmed.

## Goals

- Identical battle state always produces identical projected and actual turn order.
- The active combatant remains entry zero until their turn ends.
- CT may become negative so repeated delays create real recovery debt.
- Every turn-ending action has an exact authored CT percentage.
- Equipment and conditions may modify action CT multiplicatively.
- Action selection previews recovery and direct CT effects through the same simulation used for actual turn selection.
- The queue becomes a horizontal row of rounded portrait cards at the top of combat.
- Fixed, layered perimeter gauges communicate cumulative hard ticks from the active turn.

## Non-goals

- Final enemy portrait or sprite art.
- Rewriting the existing action-description and rich-tooltip system.
- Non-turn-consuming free actions. Ordinary turn-ending actions retain a minimum CT percentage.
- New save migrations or compatibility handling for prototype content.
- Broad combat-card or action-bar redesign beyond the selected-action CT percentage.
- Balance tuning beyond mechanically migrating existing self-acceleration effects.

## Signed CT model

`BattleManager.TARGET_CT` remains `5000`. CT is signed progress toward that threshold:

- `5000` or greater is ready.
- `0` is the normal state after beginning a turn.
- Positive CT below the threshold advances the next turn.
- Negative CT represents recovery debt and delays the next turn.

Direct CT effects are unbounded. A 10% delay subtracts `500` CT, and repeated triggers may continue below zero. This permits effects such as "each time an enemy hits you, delay their next turn by 10%."

Effective Speed is clamped consistently to a minimum of `1` anywhere CT time is calculated or advanced. The simulator must never calculate arrival using one Speed value and advance CT using another.

## Action CT percentage

Every `Action` owns an integer `ct_cost_percent`, defaulting to `100`.

- `100%` is standard recovery and leaves the actor at `0` CT before other adjustments.
- Values below `100%` advance the actor's next turn.
- Values above `100%` delay the actor's next turn.
- Ordinary actions have a final range of `10%` through `200%`.

The recovery adjustment is:

```text
recovery CT adjustment = TARGET_CT * (100 - final CT percent) / 100
```

Examples with a `5000` threshold:

```text
200% -> -5000 CT
125% -> -1250 CT
100% ->     0 CT
 75% -> +1250 CT
 25% -> +3750 CT
 10% -> +4500 CT
```

The adjustment is added to the actor's current signed CT rather than replacing it. Reactive boosts and delays incurred during action execution therefore survive action recovery.

An ordinary action may not use `0%`. A future genuinely instant action must be modeled explicitly as a non-turn-consuming free action with its own availability limit; it must not manufacture a zero-tick new turn or fire turn lifecycle events again.

## Action CT modifiers

The authored action percentage is multiplied by every applicable action-recovery modifier:

```text
final = round(base action CT * condition multiplier * equipment multiplier ...)
final = clamp(final, 10, 200)
```

Modifiers combine multiplicatively. An `80%` action with `90%` equipment recovery and an `80%` buff becomes `58%` after rounding.

`ActorCard` is the aggregation boundary. Conditions expose an action CT multiplier, and equipment participates through the existing active-trait system. `BattleManager` consumes the actor's final result without knowing which condition or equipment supplied it.

The final CT percentage is snapshotted when execution begins. Conditions applied, removed, or consumed during the action do not retroactively change that action's recovery after the preview was shown.

## Turn lifecycle

When an actor becomes ready:

1. Advance every living actor by the selected number of ticks using its clamped effective Speed.
2. Set the winner's CT to `0` and mark it as the active actor.
3. Keep an explicit active-turn entry at the head of every ordinary and preview projection.
4. When a turn-ending action begins, snapshot its final CT percentage.
5. Execute direct action effects and reactions. Any signed CT changes apply immediately.
6. Add the snapshotted action-recovery adjustment to the actor's current CT.
7. Run `ON_TURN_END` behavior, including persistent end-of-turn CT effects.
8. End the active turn and choose the next actor through the same deterministic simulator used for previews.

Existing shift actions remain non-turn-ending and do not apply action recovery.

## Existing content migration

Existing positive `Effect_ModifyCT` effects migrate into `ct_cost_percent` only when the direct action effect resolves exclusively to the acting user.

For example, an action that currently says "boost this hero's next turn by 25%" becomes a `75%` CT action and loses that direct self-boost effect.

The following remain direct signed CT effects:

- boosts granted to another actor;
- enemy delays;
- group CT manipulation;
- conditional or triggered CT effects;
- reactive effects that may occur independently of action recovery.

The migration must avoid applying both a reduced action percentage and the old self-boost for the same authored behavior.

The signed direct-effect property uses neutral terminology such as `ct_change_percent`: positive values advance a turn and negative values delay it. Unused competing action CT helpers and the unused action-level `update_turn_order` flag are removed as part of the focused cleanup.

## Deterministic simulation and ties

The projection is ordered by:

```text
earliest tick
-> higher effective Speed
-> heroes before enemies
-> immutable battle spawn priority
```

Each actor receives a stable battle priority when the encounter is created. Hero priority follows party order. Enemy priority follows encounter order and therefore agrees with existing A/B/C duplicate suffixes. Defeat and revival do not change the actor's priority.

Random tie-breaking is removed. The preview and actual turn selection call the same ordering logic, so hovering an action with no CT consequence cannot move an equal-tick actor.

Projection operates on copied simulation records and supplied preview adjustments. It does not temporarily modify live actor CT and later restore it.

## Projection contract

Every queue projection contains:

- entry zero: the active actor at cumulative tick `0`, while a turn is active;
- following entries: future turns with cumulative integer ticks measured from the active turn;
- repeated entries when a fast actor is projected to act more than once.

Ordinary refreshes, action selection, target hover, condition changes, deaths, revival, Speed changes, and direct CT changes all publish this same shape. Action preview adds the snapshotted recovery adjustment and applicable direct CT effects before simulating future turns.

Queue item identity accounts for repeated occurrences of the same actor instead of treating actor reference alone as unique. Obsolete movement and gauge tweens are canceled when a newer projection arrives.

## Horizontal queue presentation

The queue moves to the top of the combat UI as a horizontal list of rounded portrait cards.

Temporary interior content is:

- heroes: the current role/class icon;
- enemies: a generated uppercase abbreviation from the combat name, preserving the existing A/B/C suffix for duplicate enemies.

Future enemy portrait crops replace only the interior content. They do not change the projection or gauge contract.

The active entry uses a gold perimeter regardless of faction. Projected hero turns use cyan gauges, and projected enemy turns use magenta gauges.

## Fixed tick-band gauge

Each projected portrait has a rounded-rectangle perimeter gauge comparable to a circular progress graph. It represents cumulative hard ticks from the active turn, not a percentage of the current visible projection and not merely the gap from the preceding entry.

The gauge uses three fixed bands of `20` ticks each:

- first shade: `0-20` ticks;
- second, darker shade: `21-40` ticks;
- third, darkest shade: `41-60` ticks;
- `60+` ticks: saturated at all three full bands.

Hero bands use progressively darker cyan shades. Enemy bands use progressively darker magenta shades. The fixed scale never changes when actors enter, leave, or move within the projection.

The current turn uses a full gold perimeter rather than a tick gauge. Numeric tick labels used in design mockups are not required in the final battle UI.

## Selected-action CT display

The selected-action panel displays only the final effective value:

```text
75% CT
```

It does not show a calculation breakdown or the word "cost."

The number is:

- white when the final value equals the action's authored percentage;
- green when modifiers make the action faster;
- red when modifiers make the action slower.

Color comparison is against that action's authored percentage, not against `100%`. Existing action description text is not rewritten as part of this work.

## Verification

Focused automated coverage protects:

- negative CT requiring proportionally more ticks to become ready;
- repeated direct delays stacking below zero;
- `10%`, `100%`, and `200%` action recovery;
- multiplicative modifier rounding and both clamps;
- recovery adding to, rather than replacing, reactive CT changes;
- action-recovery snapshot stability when conditions change during execution;
- self-acceleration content migration without double application;
- other-target and conditional CT effects remaining direct effects;
- active actor remaining projection entry zero through every refresh path;
- deterministic Speed, faction, and stable-priority tie-breaking;
- repeated identical projections producing identical order;
- a non-CT hover leaving the projection unchanged;
- preview and execution producing the same projected next turn;
- consistent minimum effective Speed;
- fixed 20-tick gauge bands and `60+` saturation;
- hero role-icon, enemy-abbreviation, faction-color, and gold-current presentation;
- repeated actor occurrences receiving distinct queue items;
- rapid updates settling to the newest projection without stale tweens.

Because this affects turn selection, action execution, conditions, Speed, targeting previews, and the combat scene, final verification includes the complete automated suite plus manual combat checks for queue readability and animation behavior.
