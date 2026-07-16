# CTB Scrollable Rail and Animation Design

**Date:** 2026-07-15
**Status:** Approved

## Purpose

Refine the combat turn-order presentation into a compact, readable, animated timeline. This presentation revision supersedes the fixed oversized active-card and separate active-name portions of the earlier CTB queue design. CT simulation, recovery percentages, deterministic ordering, and normalized Speed rules do not change.

## Visual Structure

The complete turn order lives inside one tall, narrow, rounded black rectangle at 90% opacity on the right side of combat. The backing panel covers the existing rail footprint and sits behind all entries, gauges, and scroll feedback. It must not extend the queue's mouse-interaction region beyond the rail.

The rail contains one unified vertical scroll view. The current occurrence is the first item in the same scrolling list as every future occurrence; it is not pinned. Every entry is a 72 by 72 pixel square with equal spacing. The current occurrence is identified only by its gold perimeter gauge. It is not enlarged and has no separate name label.

The selected-action panel must no longer reserve space for the removed active name. It may reclaim that width so long as it does not overlap the queue rail.

## Entry Content and Color

Hero entries display the current role icon tinted with the role's authored color. A role shift updates every visible occurrence of that hero.

Enemy entries display the existing stable abbreviation. The abbreviation uses the project's Archivo font and the bright magenta used by the outer enemy CT gauge (`CTBGauge.ENEMY_COLOR`). The active occurrence retains the same entry content; its gold perimeter is sufficient to show current-turn state.

The rail backing supplies overall contrast, while every entry uses a fully opaque faction-tinted near-black interior so bright battlefield art cannot show through its icon or abbreviation. Hero interiors use dark cyan `#04151B`; enemy interiors use dark magenta `#1B0615`. Both retain the existing rounded interior geometry. The tint is deliberately subtle enough that the bright perimeter, role icon, and enemy abbreviation remain the primary faction signals.

## Gauge Composition

Each non-current CT gauge begins with the existing subtle dark-gray perimeter track and paints one continuous six-pixel faction-colored readiness arc over it: bright cyan for heroes or bright magenta for enemies. The arc has one fixed origin at the top-center of the rounded square and grows clockwise as the occurrence approaches its turn.

The readiness arc uses a fixed absolute 0-to-80-tick scale rather than normalizing against the visible projection. At 80 or more ticks away the arc is empty; 60 ticks is one quarter full, 40 is half full, 20 is three quarters full, and 0 ticks is full. Values above 80 remain empty. This stable mapping ensures an unrelated queue change or hover preview never changes an occurrence's gauge unless its projected tick distance actually changed.

The square's side midpoints and corners provide the quarter landmarks. The gauge uses no shade changes, nested strokes, separator lines, or disconnected pips. Delays drain the arc toward the top-center origin; boosts fill it forward. Existing 0.3-second interpolation remains.

The current queue occurrence remains a single full gold perimeter using `CTBGauge.CURRENT_COLOR` (`#FFC94A`). If another non-current occurrence is also projected at 0 ticks because of an exact tie, it remains fully faction-colored until it becomes the actual current occurrence.

## Acting Unit Outline

The battlefield card belonging to `BattleManager.current_actor` shows a persistent `#FFC94A` outline for the full acting turn. Hero and enemy cards use the same gold as the current queue occurrence.

The acting outline is an independent turn-state layer beneath the existing target outline and target pulse. Hover, available-target, and selected-target presentation may appear simultaneously without hiding or replacing the gold acting outline. The outline clears when the actor's turn ends and transfers when the next turn begins.

## Scrolling

The entire list scrolls, including the current occurrence. Mouse wheel, touch drag, and right-stick scrolling continue to share the same scroll container.

The vertical scrollbar is inset inside the rounded black rail rather than hanging beyond the screen edge. At scroll position zero it is hidden. Once the user scrolls away from the top it becomes visible and remains visible until the rail returns to the top, making displaced scroll state obvious.

Hover-only CT previews preserve the user's current scroll position. Committing an action or advancing the turn snaps the rail to the top before applying the new committed transition.

## Timeline Animation

Queue entries are matched by stable projected occurrence identity: actor plus that actor's occurrence index in the projection. Surviving occurrences reuse their existing controls instead of being rebuilt.

On a committed turn transition:

- the outgoing current occurrence slides left beyond the rail while fading out over the existing 0.3-second transition;
- the outgoing occurrence temporarily draws above the surviving entries so the promoted entry cannot cover it during their crossing motion;
- remaining occurrences slide toward their new vertical positions;
- the new current occurrence remains the same 72 by 72 size and gains the gold gauge state;
- each perimeter gauge interpolates from its previous band progress to its new value during the same transition.

The leftward exit applies only to the consumed current occurrence during a committed `ADVANCE`. Preview-only removals and non-current entries continue to use the ordinary fade exit so speculative queue changes do not read as consumed turns. The exit and promotion run simultaneously; the queue does not pause before sliding the surviving entries upward.

When Fast, Slow, direct CT changes, or other timing effects reorder future turns, entries visibly cross and swap positions as they tween to the new projection. Hover previews use this same animation and animate back when the preview clears.

Rapid preview or queue updates cancel or replace stale position, fade, and gauge tweens. The final visual state must always match the latest projection, with no delayed callback restoring obsolete positions, gauge values, visibility, or scroll offsets.

## Behavior Boundaries

- The rail consumes projected actor, occurrence, tick, faction, and current-state data; it does not calculate combat order.
- Presentation animation never mutates live CT or projected CT data.
- Repeated future turns for the same actor remain distinct occurrences.
- Empty projections clear all entries, reset scrolling to the top, hide the scrollbar, and leave no active tweens.
- Existing input ownership remains unchanged: right-stick scrolling must not change combat selection.

## Verification

Automated coverage will protect:

- uniform 72 by 72 entry sizing and removal of the separate active name;
- one scroll container containing current and future entries;
- role-color icon tint, Archivo enemy font, bright-magenta enemy text, and opaque faction-tinted near-black entry interiors;
- 90%-opaque rail backing and the fixed inverse 0-to-80-tick single-color readiness arc with a top-center origin;
- persistent gold acting-card outline on hero and enemy turns without disrupting target presentation;
- inset scrollbar visibility at the top and away from the top;
- preview scroll preservation and committed-update snap-to-top behavior;
- stable occurrence reuse, outgoing fade, position swaps, and gauge interpolation;
- stale tween cancellation under rapid projections;
- empty-queue cleanup and unchanged right-stick selection behavior.

Manual acceptance at the 1920 by 1080 reference viewport will confirm contrast, opaque faction-tinted interiors, top-center gauge origin, quarter readability, readiness-fill direction, acting-card/queue visual correspondence, readable crossing animations, scrollbar placement, and mouse/controller/touch feel.
