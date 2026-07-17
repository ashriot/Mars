# Hub Controller Cursor Design

## Summary

Replace the hub's pulsing focus and inactive-edge darkening with a controller-only software cursor. The cursor points to the exact logical focus target from outside its lower-right corner, while focused buttons use their existing authored hover appearance without animation. Mouse and keyboard handoff hides the software cursor and preserves the independent physical mouse position.

This design supersedes the exact-focus pulse, hub focus-style mutation, inactive-depth chrome, and “no software pointer” decisions in `2026-07-16-hub-controller-navigation-design.md`. It also amends the focus presentation described in `2026-07-16-hub-role-depth-and-xp-design.md`. The approved role depths, controls, role-name swap, XP presentation, stable focus, controller glyphs, and modal ownership remain unchanged.

## Scope

The controller cursor applies only inside party management:

- hero panels;
- role panels and progression nodes;
- rank-page controls;
- equipment rows, modification slots, and inventory items; and
- other ordinary focusable hub controls introduced later.

Battle, dungeon, scan, terminal, and non-hub menu presentation do not change. The existing scan-specific software-pointer behavior remains independent.

## Presentation

The existing up-left-pointing pointer artwork is reused at `128x128` for hub navigation while the scan pointer retains its original size. At rest, the hub cursor slightly overlaps the focused control's lower-right edge without crossing its readable center.

When the requested outside position would clip the pointer against the viewport, the complete cursor rectangle is clamped inside a small screen margin. This may bring it against the target's lower-right corner, but it must not move across the control's readable center.

Controller focus changes logical target immediately. The visible cursor moves to the new anchor with a `70 ms` ease-out tween. A newer focus target cancels and replaces an in-flight cursor tween. The cursor then breathes by drifting `12 px` diagonally away over `650 ms` and returning over `160 ms`; breathing pauses and resets during focus travel. Initial appearance, focus restoration after a hidden or freed target, and mouse takeover do not wait for a tween before input becomes valid.

The cursor continuously follows the target's current global rectangle while the target moves because of:

- hero or role expansion/collapse;
- scrolling;
- responsive profile or viewport changes;
- animated layout changes; or
- focus restoration after rebuilding content.

A hidden, disabled, freed, off-tree, or non-hub target hides the hub cursor until the navigation layer resolves a valid hub focus target.

## Focused control appearance

The hub cursor is the sole custom exact-focus marker. Hub focus no longer:

- pulses a fill, border, or panel;
- flashes opacity or brightness;
- changes label, icon, stat, gauge, or content colors;
- adds a new white outline; or
- darkens inactive hero or content edges.

Focusable buttons may use their existing authored mouse-hover appearance as a static controller-focus style. The navigation layer derives this from the control's existing theme rather than synthesizing mouse motion or inventing another color. Removing focus restores the authored normal state exactly.

Non-button focus targets such as hero and role panels retain their authored visuals. Their expanded/collapsed state communicates persistent selection, and the cursor alone identifies exact controller focus.

Mode-specific authored state remains valid when it is part of gameplay meaning rather than navigation focus, but it must not pulse whole content. Equipment, tune, and modification selection continue to use their dedicated edge-only indicators until separately redesigned.

## Input ownership and handoff

Meaningful controller input inside the hub:

- keeps ordinary logical Godot focus authoritative;
- shows the hub software cursor at the focused target;
- applies the target's static authored hover treatment when supported; and
- hides the physical hardware cursor through the existing `InputManager` policy.

Keyboard input, a physical mouse click, or direct pointer presentation hides the hub software cursor immediately. A mouse click reveals the hardware cursor at its actual physical position and resumes ordinary direct hover and click behavior. Neither cursor is warped to the other's position. The apparent jump is a presentation handoff between two independent cursor authorities.

Small or large physical mouse motion while controller mode remains authoritative continues to follow the existing input-ownership rules. The software cursor never generates synthetic mouse events, changes the physical mouse position, or drives hit testing.

Only one visible pointer authority may exist at a time:

- controller-owned hub navigation: hub software cursor visible, hardware cursor hidden;
- keyboard/mouse pointer presentation: hub software cursor hidden, hardware cursor visible; or
- scan-specific controller pointer: scan cursor policy remains authoritative and the hub cursor is hidden.

## Architecture

`NavigationUXLayer` continues to own logical focus, modal trapping, and input-family presentation. It additionally decides whether the current focus belongs to the visible party menu and, if so, supplies that target to `NavigationCursor`.

`NavigationCursor` owns hub pointer positioning, the `70 ms` replacement tween, viewport clamping, target tracking, and immediate hide/show cleanup. It never owns navigation state or activates controls.

`NavigationFocus` stops applying hub pulse metadata and inactive depth colors. Its ordinary non-hub focus treatment remains unchanged. For hub buttons it applies and restores only the authored static hover-equivalent style required by this design.

Hub controls may expose optional cursor-anchor metadata only when the default lower-right global-rectangle anchor is visually unsuitable. The default must work for the current hero, role, node, page, equipment, modification, and inventory controls; per-control offsets are exceptions rather than a parallel layout system.

`HubChrome` is removed from hub depth transitions or becomes unused by those transitions. Authored panel styles remain unchanged at every hub depth.

## Automated verification

Regression coverage protects:

- controller focus shows one `128x128` software cursor slightly overlapping the target's lower-right edge;
- cursor movement completes in `70 ms`, and a newer target replaces an in-flight tween;
- position-only breathing moves slowly away and quickly returns, and stops during focus travel or non-hub ownership;
- viewport-edge targets keep the complete cursor visible without moving over readable content;
- cursor tracking follows scrolling and animated panel movement;
- controller cursor movement does not alter the physical mouse position;
- mouse click and keyboard handoff hide the software cursor immediately;
- leaving the hub, opening a focusless modal, freeing a target, or changing to a non-hub screen hides it;
- hub buttons receive and restore their authored hover-equivalent style without pulsing;
- hero, role, XP, stats, costs, EP, items, and gauges retain authored colors during navigation;
- inactive hub regions retain authored border brightness;
- no synthetic mouse event is required to produce controller focus presentation; and
- battle, dungeon, scan, terminal, and ordinary non-hub focus tests remain unchanged.

Final verification includes focused cursor, input-manager, navigation-layer, hub progression, standard-focus, responsive hub, and controller-loop tests followed by the complete isolated-`HOME` suite.

## Manual acceptance

At `1920x1080` and `1280x800`, verify with a physical controller that:

- the cursor clearly identifies heroes, roles, nodes, pages, equipment, mods, and inventory items;
- its lower-right placement does not cover readable content;
- its short tween communicates direction without producing lag or ambiguity;
- its slow-away, quick-return breathing remains visible without feeling distracting;
- rapid navigation never leaves duplicate cursors or a cursor between targets;
- edge clamping keeps the complete pointer visible;
- buttons show their familiar hover appearance without flashing;
- every panel retains its intended authored brightness and color;
- role and hero expansion remains sufficient persistent-selection feedback;
- a mouse click causes an immediate, unsurprising handoff to the physical pointer; and
- returning to controller input restores the software cursor at the current logical focus.
