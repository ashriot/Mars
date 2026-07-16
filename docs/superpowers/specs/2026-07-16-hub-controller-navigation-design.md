# Hub Controller Navigation Design

## Summary

Redesign party management around a controller-first layered navigation model while preserving direct mouse and touch operation. Move the mode tabs to the top, expand the strip to Roles, Items, Options, and Journal, and use L2/R2 to cycle those top-level tabs. Keep the current vertical hero rail and the existing expanded/collapsed selection language.

Controller focus is communicated without a software pointer. The exact focused control receives an opt-in neutral background pulse derived from battle targeting, while navigation depth is shown by darkening inactive borders and glow chrome. Text, icons, stats, costs, and other content remain fully readable at every depth.

This design supersedes the Hub Navigation binding and focus hierarchy in `2026-07-11-controller-navigation-design.md`. Its global input ownership, modal trapping, semantic glyph resolution, and stable-focus principles remain authoritative.

## Goals

- Make the current controller focus unmistakable without adding a software cursor.
- Keep hero switching fast and spatially consistent with the vertical hero rail.
- Make Back move outward through a predictable party-management hierarchy.
- Give top-level sections dedicated, visible controller shortcuts.
- Preserve the dense hub's at-a-glance readability.
- Keep mouse and touch interaction direct and synchronized with controller state.
- Support additional top-level tabs without restructuring the shell.
- Preserve the existing responsive targets at `1920x1080` and `1280x800`.

## Non-goals

- Implementing real Options or Journal features.
- Adding dedicated keyboard shortcuts for hub tabs, roles, or rank pages.
- Adding a software pointer or warping the hardware pointer.
- Redesigning progression rules, equipment behavior, hero stats, role content, or inventory transactions.
- Changing focus presentation on non-hub screens.
- Replacing the current expanded/collapsed hero and role presentation.

## Current problems

The party menu was composed around pointer input. Heroes form a vertical rail on the left, progression or equipment content fills the right, and Roles/Items mode controls sit below the hero rail. The current controller path starts on the bottom mode controls, hero panels are not ordinary persistent controller targets, and Back performs much of the movement between otherwise unclear focus layers.

The existing visuals already communicate persistent selection:

- the selected hero panel is expanded while other hero panels are collapsed;
- the selected role panel is expanded and retains its authored role color; and
- current progression and equipment state is represented inside the active content.

What is missing is an equally clear transient focus state showing exactly which hero, role, node, item, or equipment control will respond to Confirm. Making entire regions translucent would reduce the readability of dense stats and progression data, while bright region outlines would compete with the existing white and neon panel language.

## Information architecture

The party-management shell has two navigation depths:

1. `HERO_RAIL` selects the hero whose information is displayed.
2. `CONTENT` operates the active top-level tab for that hero.

The top tab strip is ordered:

1. Roles
2. Items
3. Options
4. Journal

Roles and Items contain their current functional views. Options and Journal are selectable stubs that display a centered `COMING SOON` message. Stub views have no fake actionable control.

The vertical hero rail remains in its current location. It does not become a horizontal carousel, and hero selection does not receive a left/right shoulder shortcut.

## Controller mapping

### Global party-menu controls

- L2: previous top-level tab.
- R2: next top-level tab.
- Up/Down in the hero rail: immediately select another hero.
- Right or Confirm on the selected hero: enter the active tab's content when it has actionable content.
- Left from the content's left boundary: return to the selected hero.
- Back in ordinary content: return directly to the selected hero.
- Back in the hero rail: close party management.

Top tabs wrap in both directions. Tab switching is available from either navigation depth. Roles and Items remember their last valid content focus per hero. Switching between functional tabs while in content restores the destination tab's remembered focus and keeps content depth. Switching to Options or Journal returns focus to the selected hero because the stub has no actionable content. Returning from a stub to Roles or Items begins from the hero rail.

### Roles controls

- L1: previous role tree.
- R1: next role tree.
- D-pad/left stick: geometric navigation among the current tree's nodes and spatial navigation to the visible rank-page controls.
- Confirm: inspect or purchase according to the existing progression rules.
- Back: return directly to the selected hero.

L1/R1 role switching replaces the current L2/R2 role binding. Rank pages no longer use a dedicated L1/R1 shortcut. Their visible `1–10`, `11–20`, and later controls remain mouse/touch clickable and controller reachable through spatial D-pad navigation. Reaching rank-page controls does not add another Back layer.

### Items controls

Ordinary directional navigation continues among equipment, tuning, modification, and inventory controls. Back unwinds a nested Items transaction before leaving content:

1. modification, tuning, or equip mode returns to ordinary Items view;
2. ordinary Items content returns to the selected hero; and
3. the hero rail closes party management.

Existing validated equipment and inventory transactions do not change.

## Hero selection and focus

Opening party management focuses the currently selected, expanded hero. If that hero is unavailable, the first valid hero is selected deterministically. The existing empty-roster behavior remains unchanged and does not open an unusable menu.

While `HERO_RAIL` owns focus, Up/Down immediately commits the newly focused hero:

- the new hero expands and begins pulsing;
- the previous hero collapses and stops pulsing;
- the active functional tab updates to the new hero; and
- remembered content context is prepared but content focus is not entered.

There is no separate hover-before-selection state in the hero rail. The pulsing hero is always the selected expanded hero.

When focus enters content, the selected hero remains expanded as persistent context but stops pulsing. The exact content control begins pulsing instead. Returning to the hero rail reverses that ownership without changing the selected hero.

## Visual language

The hub represents three concepts independently.

### Persistent selection

Selection continues to use the current authored language:

- selected heroes and roles are expanded;
- authored white, yellow, green, and other content colors remain intact; and
- selected content stays fully readable.

No new orange selection accent is added because it would conflict with existing role and stat coloring.

### Exact controller focus

The exact controller target receives a neutral white background pulse. The fill moves smoothly between lower and higher opacity while preserving the control's shape. This follows the battle target-pulse concept, but it is an opt-in hub focus style rather than a change to battle targeting or global menu focus.

Only one hub focus pulse may run at a time. Moving focus, switching input ownership, hiding or freeing a control, changing tabs, closing the menu, or leaving the scene stops and restores the previous surface cleanly.

Mouse/pointer presentation continues to use the established hover and input-ownership rules. A hardware or software cursor is not attached to focused hub controls.

### Navigation depth

Depth changes only surrounding chrome:

- in `HERO_RAIL`, hero-panel borders retain their normal brightness while content-panel neon borders and glows use a much darker hue-related variant;
- in `CONTENT`, the selected hero retains its normal border while collapsed unselected hero borders darken, and active content chrome returns to full authored brightness; and
- labels, icons, stats, node text, costs, gauges, and content backgrounds do not receive whole-region opacity reduction.

Chrome transitions should be brief and subtle. They communicate ownership without delaying input or obscuring comparison data.

## Tab and shortcut presentation

The top strip visibly associates L2 with the left side and R2 with the right side. The active Roles view similarly associates L1/R1 with previous/next role switching. Glyphs resolve through the existing controller-family system for PlayStation, Xbox/Steam, Nintendo, Steam Deck, and generic controllers.

Embedded shoulder glyphs are controller-only affordances:

- meaningful controller input fades the relevant glyphs in;
- keyboard input, a physical mouse click, or touch input fades them out;
- the reserved glyph space remains in layout so labels do not shift during handoff;
- the fade is approximately `150–200 ms`; and
- keyboard/mouse mode does not substitute Q/E, Z/C, or other keyboard glyphs.

Mouse and touch users activate visible tabs and controls directly. Standard directional keyboard navigation, Confirm, and Back may continue to operate through the ordinary focus system, but no new direct keyboard shortcuts are defined or advertised for tab, role, or rank-page cycling.

## Component responsibilities

### `PartyMenu`

- Owns the ordered top-tab descriptors and current tab ID.
- Owns `HERO_RAIL` versus `CONTENT` depth.
- Owns the selected hero index and immediate Up/Down hero selection.
- Routes L2/R2 tab actions and Back/Left depth transitions.
- Coordinates active/inactive chrome presentation without reducing content opacity.
- Requests focus restoration from functional tabs and falls back to the selected hero.
- Displays Options and Journal stub content.

### Functional tab views

Roles and Items expose narrow navigation boundaries for:

- remembering their current stable focus identity;
- restoring a valid focus target for a hero;
- providing a deterministic fallback target; and
- unwinding a nested interaction before PartyMenu changes depth.

Roles keeps stable node-ID, role, and rank-page memory. Items remembers stable equipment or item context where possible and otherwise chooses a deterministic first valid control.

### Hub controls and panels

Hero, role, skill-node, equipment, modification, item, and tab components expose the appropriate focus surface and chrome-depth presentation. Depth styling changes border/glow resources or dedicated chrome overlays rather than whole-control modulation.

### Shared navigation presentation

The shared focus layer supports an opt-in pulsing fill for hub controls. Its current solid focus treatment remains the default everywhere else. The pulse implementation stores and restores authored styles and foreground colors just as ordinary focus presentation does, and it owns cleanup of its tween.

### Dynamic glyph presentation

Controller-only shoulder glyphs reuse semantic controller-family resolution but opt out of keyboard texture substitution. They retain layout space while fading between controller and keyboard/mouse ownership.

## Invalid and changing focus

- A hidden, disabled, freed, or rebuilt remembered control resolves to the tab's deterministic fallback.
- If a functional tab has no valid content target, focus returns to the selected hero rather than becoming null.
- Options and Journal always return focus to the selected hero.
- Rebuilding a skill tree restores by stable node ID when possible, then the nearest sensible node according to existing progression navigation rules.
- Rebuilding inventory restores an equivalent stable context when possible and otherwise the first enabled visible control.
- Modal ownership remains authoritative. Underlying hub shortcuts, focus movement, and transactions do not leak through a nested modal.
- Rapid input-family switching never leaves both pointer hover and controller focus pulse presented as authoritative.

## Automated verification

Focused automated coverage protects:

- initial focus on the selected expanded hero;
- immediate Up/Down hero selection, expansion, content refresh, and single-pulse ownership;
- Right/Confirm content entry and Left/Back return to the selected hero;
- nested Items Back behavior before depth exit;
- Back from the hero rail closing party management exactly once;
- L2/R2 wrapping across Roles, Items, Options, and Journal from both depths;
- L1/R1 switching roles only while Roles content is active;
- spatial access to rank-page controls without an additional Back layer;
- per-hero, per-tab, per-role, per-page, and stable-node focus restoration;
- deterministic fallback when remembered controls disappear or become invalid;
- Options and Journal `COMING SOON` content and hero-rail focus fallback;
- opt-in hub pulse lifecycle without changing non-hub focus presentation;
- chrome depth changes preserving content opacity and authored foreground colors;
- controller-family glyph resolution, controller-only visibility, retained layout space, and input-mode fade transitions;
- synchronized mouse/touch hero and tab selection; and
- responsive layout and minimum control sizes at `1920x1080` and `1280x800`.

Because the change crosses hub input, modal focus, progression navigation, inventory navigation, responsive layout, and shared presentation, final automated verification runs the complete GUT suite with the repository's mandatory isolated `HOME`.

## Manual verification

Update the controller manual checklist and verify at both supported viewports:

- top tabs remain readable, balanced, and directly clickable;
- L2/R2 and L1/R1 glyph placement clearly communicates hierarchy for every controller family;
- controller glyphs fade without layout shift during keyboard, mouse, touch, and controller handoff;
- hero expansion and focus pulse make the current hero unmistakable;
- content focus pulse remains obvious across bright yellow, green, and other authored role palettes;
- inactive chrome is visibly recessed without reducing the readability of stats, icons, costs, or node text;
- Back consistently unwinds Items modes, returns to the hero rail, and then closes the menu;
- Roles, Items, Options, and Journal wrap correctly without stale focus or stale chrome;
- rank pages and every role remain reachable without pointer input;
- mouse/touch interaction updates controller selection and restoration context correctly; and
- rapid alternation never produces two pulses, two authoritative highlights, or a null focus target.

Pulse cadence, chrome contrast, physical controller feel, and rapid visual readability are manual acceptance concerns rather than screenshot-comparison assertions.
