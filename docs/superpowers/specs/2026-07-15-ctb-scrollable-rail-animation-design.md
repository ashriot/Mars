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

Enemy entries display the existing stable abbreviation. The abbreviation uses the project's Archivo font and the bright magenta used by the outer enemy CT gauge (`CTBGauge.ENEMY_COLORS[0]`). The active occurrence retains the same entry content; its gold perimeter is sufficient to show current-turn state.

The rail backing supplies contrast for both hero icons and enemy text. Individual entries retain their existing dark interior treatment only where needed for legibility; the result should read as one unified rail rather than a stack of unrelated black panels.

## Gauge Composition

Each non-current CT gauge begins with the existing subtle dark-gray perimeter track. The three 20-tick faction bands are then painted over that track in light, medium, and dark cyan for heroes or magenta for enemies.

All three faction strokes use the same six-pixel width and are fully opaque. The light band paints first, the medium band paints over it, and the dark band paints last. A partial later band covers only its filled fraction of the same perimeter. The bands never use progressively narrower widths, so the result has no concentric or nested colored lines.

The current queue occurrence remains a single full gold perimeter using `CTBGauge.CURRENT_COLOR` (`#FFC94A`).

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
- role-color icon tint, Archivo enemy font, and bright-magenta enemy text;
- 90%-opaque rail backing and same-width light/medium/dark gauge overlays;
- persistent gold acting-card outline on hero and enemy turns without disrupting target presentation;
- inset scrollbar visibility at the top and away from the top;
- preview scroll preservation and committed-update snap-to-top behavior;
- stable occurrence reuse, outgoing fade, position swaps, and gauge interpolation;
- stale tween cancellation under rapid projections;
- empty-queue cleanup and unchanged right-stick selection behavior.

Manual acceptance at the 1920 by 1080 reference viewport will confirm contrast, rounded-rail composition, non-nested gauge readability, acting-card/queue visual correspondence, readable crossing animations, scrollbar placement, and mouse/controller/touch feel.
