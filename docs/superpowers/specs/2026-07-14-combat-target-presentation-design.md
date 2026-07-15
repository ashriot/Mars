# Combat Target Presentation Design

## Status

Approved for implementation on 2026-07-14.

## Problem

Combat currently animates every valid target while an action is awaiting a choice, but it does not give the single current target a stronger, unambiguous state. Removing the old controller cursor/card presentation exposed this weakness: controller and keyboard navigation can change the logical target without a sufficiently clear visual result. Enemy mouse hover updates the CTB preview, hero targeting lacks an equivalent hover presentation, and the active hero's blinking outline competes with target feedback.

The combat target UI needs one input-agnostic target model that distinguishes eligibility from selection, drives CTB preview consistently, and works identically for hero and enemy unit cards.

## Goals

- Make valid targets immediately recognizable without animating all of them.
- Make the current single target unmistakable for mouse, keyboard, and controller input.
- Use the same presentation states for hero and enemy cards.
- Keep CTB delay preview synchronized with the visible target.
- Give controller targeting a useful remembered default while allowing mouse/keyboard targeting to begin unselected.
- Remove the active hero's blinking outline and retain its existing slide-up/down turn indicator.
- Preserve the input-ownership and first-click handoff rules established by the input ownership design.

## Non-goals

- Redesigning the combat card layout, CTB layout, action bar, or turn-order simulation.
- Redesigning the hub UI. The hub visual cleanup is a separate future effort.
- Adding a software cursor, target reticle, target card, or hardware mouse movement.
- Changing target eligibility, action execution, delay values, battle balance, or AI behavior.
- Changing enemy intent presentation.

## Visual hierarchy

Every `ActorCard`, whether hero or enemy, supports three target-presentation states:

1. `NORMAL`
   - Uses the authored card appearance without a targeting overlay.
   - Applies to ineligible cards and to every card outside target selection.
2. `AVAILABLE`
   - Adds a steady, bright-white outline.
   - The outline must read as valid and actionable; it must not use gray or reduced opacity that resembles a disabled state.
   - No animation is applied.
3. `SELECTED`
   - Retains the solid bright-white outline.
   - Adds a thicker outer treatment and a breathing white glow.
   - The white outline itself never fades or turns gray during the pulse.

Cards outside the eligible or selected sets remain entirely unaffected. For an all-target action, every affected card enters `SELECTED` so the full resolved target set is explicit.

The existing `TargetFlash` behavior must no longer mean "valid target." The implementation may reauthor or replace the current overlay nodes, but eligibility and selection must remain independently representable and their tweens must be owned and stopped by the card presentation API.

## Active-turn presentation

The active hero no longer flashes or blinks its highlight outline. Its existing slide-up on turn start and slide-down on turn end are the complete active-turn presentation.

This prevents active-turn feedback from competing with the white target hierarchy. Enemy active-turn presentation is outside this change unless a minimal cleanup is required to keep target overlays independent.

## Target state model

Combat owns two distinct concepts:

- **Navigation origin:** the last valid single-target card used to continue directional navigation.
- **Current target:** the visible card that is presently `SELECTED` and may be confirmed.

These values may differ temporarily in mouse/keyboard pointer presentation. A retained navigation origin is never executable while no current target is visible.

The card presentation API must be semantic, such as `set_target_presentation(state)`, rather than exposing tween or overlay-node details to `BattleScene` or `BattleManager`.

## Single-target input behavior

### Controller

Entering single-target selection restores the last valid target on the required side: enemy or hero. If that card is defeated, hidden, ineligible, or freed, targeting chooses the first valid candidate using the existing deterministic candidate order.

The restored or fallback card immediately becomes the current target and uses `SELECTED`. Directional input changes the current target immediately. The previous target returns to `AVAILABLE`.

Last hero and last enemy targets are remembered separately for the duration of the battle. Selecting a valid card updates the corresponding memory.

### Mouse and keyboard

Entering single-target selection begins with no current target. Every eligible card shows `AVAILABLE`.

- Hovering an eligible hero or enemy card makes it the current target and applies `SELECTED`.
- Hovering a different eligible card demotes the previous card to `AVAILABLE` and selects the new card.
- Moving the pointer away from every eligible card clears the current target and its target-dependent CTB preview. The prior card remains the retained navigation origin but returns to `AVAILABLE`.
- Confirm cannot execute while the current target is empty, even if a navigation origin is retained.
- If there is no retained navigation origin, the first arrow/WASD target-navigation input selects the nearest valid candidate using the existing geometry rules.
- After pointer presentation clears a visible target, the first directional input restores the retained origin without moving; the next direction navigates from it. This mirrors the standard button-focus handoff rule.

Keyboard input that takes ownership from controller mode remains deliberate and immediate. A directional key moves or establishes the current target according to the rules above. Mouse motion does not take controller ownership, and therefore cannot clear a controller-owned target.

## Mouse click handoff

The global input rules remain authoritative:

- The first mouse-button transaction after controller ownership changes to mouse/keyboard ownership and is consumed.
- Its matching release is also consumed.
- A later click may execute a visible current target.

Pointer hit testing may establish a hover target during the handoff, but the consumed transaction must never execute the action. No code may warp the hardware pointer.

## All-target and automatic actions

Actions whose target set is already resolved and does not require a single-card choice do not enter empty single-target selection.

- All affected hero or enemy cards enter `SELECTED` immediately.
- Unaffected cards remain `NORMAL` unless they are separately valid for a choice, which current authored actions do not require.
- The CTB preview is computed immediately from the resolved target set.
- Confirmation and execution behavior remain as currently authored; this design changes presentation, not whether an automatic action requires confirmation.

## CTB preview synchronization

The visible target state and the CTB preview share one source of truth.

- Selecting or hovering a single target recalculates the preview with that actor as the selected parent target.
- Changing targets recalculates the preview for the new target.
- Clearing the current target recalculates with no selected target. Target-dependent CT effects are therefore omitted, while self, action-wide, and already-resolved all-target CT effects remain visible.
- All-target actions preview every affected CT change immediately.
- Canceling, executing, replacing, or invalidating an action restores the ordinary CTB projection through the existing battle cleanup path.

The current `preview_action_turn_order(actor, action, selected_target)` seam may be retained, but all hero, enemy, mouse, keyboard, and controller target changes must route through the same target-state owner before invoking it.

## Invalid targets and cleanup

If the current target becomes invalid during selection:

- Controller mode restores the remembered valid card on the required side or falls back to the first valid candidate.
- Mouse/keyboard mode clears the current target and waits for hover or directional input.

Changing actions, canceling targeting, executing an action, ending the turn, actor defeat, battle teardown, and scene teardown must:

- stop all target-presentation tweens;
- return every affected card to `NORMAL`;
- clear the current target and any stale retained origin that is no longer valid;
- restore the ordinary CTB projection;
- leave no glow, outline, or active tween on reused or freed cards.

## Components and responsibilities

### `ActorCard`

- Owns the semantic target-presentation state.
- Shows and hides the available outline and selected pulse/glow.
- Stops and replaces its own presentation tween safely.
- Exposes no input-mode policy.

### Hero and enemy card scenes

- Provide matching target overlay structure and bright-white styles.
- Route pointer enter/exit through a common semantic target-hover path, directly or through thin hero/enemy adapters.
- Preserve authored card colors and content.

### `BattleScene`

- Owns current target, retained navigation origin, last hero target, and last enemy target.
- Applies controller versus mouse/keyboard entry policy.
- Performs geometric directional navigation and confirmation against the visible current target.
- Requests target-state and CTB updates through focused helper methods.

### `BattleManager`

- Remains authoritative for valid target calculation, action execution, and CTB simulation.
- Connects hero and enemy pointer events to the shared target-state owner.
- Clears targeting presentation through the existing cleanup lifecycle.

## Testing strategy

Automated tests should protect public state transitions and battle integration rather than tween timing details.

### Card-level coverage

- `NORMAL` hides both targeting treatments.
- `AVAILABLE` shows a steady bright-white outline and no running pulse.
- `SELECTED` keeps the bright outline and owns one pulse/glow tween.
- Repeated state assignment is idempotent.
- Returning to `NORMAL` stops the tween and restores authored presentation.
- Hero and enemy scenes expose the same target overlay contract.

### Battle integration coverage

- Choosing a single-target action marks all and only valid cards `AVAILABLE`.
- Controller entry restores the last valid same-side target, otherwise the deterministic fallback.
- Mouse/keyboard entry has no selected target.
- Hero and enemy hover select, exit clears visible selection, and confirm cannot use only a retained origin.
- First directional input establishes a target from an empty origin; pointer-cleared origin follows restore-then-move behavior.
- Target changes update target-dependent CTB preview; target clearing removes that portion.
- All-target actions select every affected card and preview all applicable CT effects.
- Invalid or defeated current targets follow the controller fallback and mouse/keyboard clearing rules.
- Cancel, execution, action replacement, turn end, and teardown clear overlays and tweens.
- Active hero turn start slides the card without starting its old blink tween.
- Existing mouse first-click consumption and no-warp tests remain green.

### Manual acceptance

- Bright-white available outlines are readable on every authored hero and enemy palette and never resemble disabled gray.
- Selected glow remains unmistakable at every point in its pulse without obscuring names, portraits, HP, guard, intent, or status content.
- Controller, keyboard, and mouse target changes feel immediate and agree with CTB preview.
- All-target actions clearly mark the complete affected set.
- Active hero slide-up is sufficient at combat speed without a competing blink.
- Rapid action changes, cancellation, defeat, and device switching leave no stale outline or glow.

## Deferred follow-up

The hub UI needs a separate visual redesign. That work should reuse the project's clarified typography and focus principles, but it is intentionally excluded from this combat-target implementation.
