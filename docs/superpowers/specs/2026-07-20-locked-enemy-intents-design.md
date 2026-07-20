# Locked Enemy Intents

## Goal

Enemy intents are reliable telegraphs. Once an enemy displays an action and its
targets, ordinary combat changes must not let it choose a different tactic before
it acts. Changes that make the displayed targets illegal may retarget the locked
action. Breach may replace the locked action with Recover.

## Decision Lifetime

- Plan every living enemy's first intent after starting passives and initial CT
  head starts have finished.
- Keep each displayed decision locked until that enemy acts.
- After an enemy completes its turn and advances its cooldown state, plan that
  enemy's next intent from the resulting battlefield state.
- HP, Guard, Focus, CT, turn-order, and ordinary condition changes do not select a
  new ability or rule for an already planned enemy.
- Breaching an enemy immediately replaces its intent with Recover. Recovery is the
  only state-driven action replacement before execution.

## Target Revalidation

Target revalidation is separate from tactical planning. It preserves the locked
action and rule and changes only the targets.

Revalidate locked targets whenever state that can affect target eligibility
changes, including:

- applying or removing a condition;
- an actor being defeated or revived; and
- future targeting mechanics expressed through the shared target-eligibility
  rules.

The existing condition flags are authoritative:

- `is_untargetable` makes that actor illegal for hostile targeting, including
  Decoy;
- `is_taunting` redirects applicable hostile single/random targeting, including
  Draw Fire.

If the current targets remain legal under the action's targeting constraints,
retain them exactly. Target legality checks only availability constraints such as
side, defeat, untargetability, and applicable Taunt; changes to selector preferences
such as highest Focus or lowest Guard do not invalidate a target. If a target does
become illegal, run the locked rule's selector again and replace only the target
list. If no legal target exists, the enemy safely spends the activation without
selecting a different action. A targeting change never re-evaluates ability
trigger conditions, priorities, or cooldown ordering.

At execution, validation checks that the locked action still exists and that its
targets are legal. It does not require the original HP, Guard, Focus, CT, or other
tactical trigger conditions to remain true.

## Intent Presentation

- Flash the intent only when the displayed action or target list actually changes.
- Repeated planning or presentation calls with the same action and targets do not
  flash.
- Damage and tooltip presentation may refresh when combat values change without
  changing the locked decision or flashing.
- A forced retarget and a Breach-to-Recover replacement flash because the
  telegraphed commitment genuinely changed.

## Runtime Boundaries

`BattleManager` owns when planning and target revalidation occur.
`EnemyCard` owns the locked decision, target-only replacement, and change-aware
intent presentation. `EnemyTargetSelector` gains a legality boundary distinct
from its ranking preferences and remains the shared source of eligible targets so
Decoy, Draw Fire, and future targeting mechanics behave consistently.

Turn-order publication remains independent from AI planning. Refreshing the CT
queue must not implicitly recalculate intents.

## Verification

Automated coverage will establish that:

- HP, Guard, Focus, and turn-order changes do not replan a locked intent;
- execution preserves an action after its original tactical trigger becomes false;
- Decoy retargets the same action away from the untargetable hero;
- Draw Fire redirects the same applicable action to the taunting hero;
- ordinary condition changes with no targeting effect preserve targets;
- death and revival revalidate affected targets without changing actions;
- Breach replaces an enemy's action with Recover;
- unchanged decisions do not flash, while real action/target changes do; and
- completing an enemy turn advances cooldowns and plans its next intent.

## Non-Goals

This change does not revise enemy ability content, cooldown values, priorities,
damage formulas, target-selector authoring, or hero action balance.
