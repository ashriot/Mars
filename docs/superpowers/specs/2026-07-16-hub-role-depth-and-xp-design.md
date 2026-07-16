# Hub Role Depth and XP Presentation Design

## Summary

Refine the controller-first hub so Roles has an explicit intermediate role-selection depth, rank pages use L2/R2, and top-level tabs use L1/R1. Correct the role-card header overlap by making abbreviated and full role names mutually exclusive. Present abbreviated hero XP beside HP on hero cards while retaining the exact spendable value as `AVAILABLE XP` in the expanded role header.

This design supersedes the Roles depth, hub-tab bindings, role bindings, rank-page bindings, role shortcut placement, and XP presentation in `2026-07-16-hub-controller-navigation-design.md`. Its hero selection, Items navigation, controller-only glyph handoff, focus-versus-selection language, stable focus restoration, and chrome rules remain authoritative.

## Goals

- Make the controller path through Roles read as Hero → Role → Tree.
- Let Back unwind one conceptual level at a time.
- Use spatial left/right input to select among the horizontally arranged roles.
- Reserve L2/R2 for rank-page changes and L1/R1 for top-level hub tabs.
- Show rank-page trigger glyphs next to the page controls they operate.
- Eliminate simultaneous abbreviated and full role-name rendering.
- Show hero XP in both a compact scanning format and an exact spending-context format.

## Non-goals

- Changing progression costs, purchasing rules, role unlock rules, or authored trees.
- Changing the established Hero → Items depth or nested Items Back behavior.
- Adding keyboard shortcuts corresponding to the new shoulder and trigger bindings.
- Adding another permanent region to the hub shell.
- Changing hero names, role names, or role identifiers in authored data.

## Navigation hierarchy

The party menu continues to own `HERO_RAIL` and `CONTENT`. Within Roles content, `SkillTreePanel` owns two explicit sub-depths:

1. `ROLE_SELECT` — the current role panel is the exact controller target.
2. `TREE` — a node or rank-page control inside the selected role owns focus.

The complete Roles path is therefore:

1. The selected hero owns focus in `HERO_RAIL`.
2. Right or Confirm enters Roles at `ROLE_SELECT`.
3. Left/Right selects a role; the selected role expands and the others collapse.
4. Confirm or Down enters `TREE` and restores that role/page's remembered node.
5. Back from `TREE` returns to `ROLE_SELECT` without changing the selected role.
6. Back from `ROLE_SELECT` returns to the selected hero.
7. Back from the hero rail closes party management.

The selected role remains expanded in both Roles sub-depths. Expansion communicates persistent role selection; the hub-only controller cursor defined in `2026-07-16-hub-controller-cursor-design.md` communicates the exact current controller target. Thus the cursor points to the expanded role in `ROLE_SELECT`, then moves to the focused node or page control in `TREE`.

Each hero remembers its selected role, current supported rank page, and stable focused node per role/page. Re-entering Roles begins at `ROLE_SELECT` for that remembered role rather than dropping directly into its tree. Entering `TREE` restores the remembered node or the existing deterministic nearest-node fallback.

## Controls

### Top-level tabs

- L1: previous top-level tab.
- R1: next top-level tab.

These bindings remain available at every ordinary party-menu depth and continue to wrap across Roles, Items, Options, and Journal. The existing controller-only glyphs surrounding the top tab strip change to the L1/R1 family equivalents. No keyboard bindings are added.

### Role selection

- Left/Right: select the previous or next role panel according to the visible horizontal order.
- Confirm or Down: enter the selected role's tree.
- Back: return to the selected hero.

Role selection does not wrap: Left on the first role and Right on the last role do nothing. It no longer has dedicated shoulder or trigger shortcuts. Mouse/touch selection of a collapsed role selects and expands that role; selecting content inside the expanded role continues to use direct pointer behavior.

### Tree navigation and rank pages

- D-pad/left stick: geometrically navigate the current tree.
- Confirm: inspect or purchase according to existing progression state.
- L2: previous supported rank page.
- R2: next supported rank page.
- Back: return to role selection.

Rank-page changes wrap across only the pages supported by the active role, preserving the existing page fallback and stable-node restoration rules. L2/R2 do nothing when fewer than two supported pages exist and do not operate from `ROLE_SELECT`, Items, Options, or Journal.

The visible page strip remains mouse/touch clickable and ordinarily focusable. Controller-only L2/R2 glyphs flank the visible rank-page controls below the tree. Glyph space remains stable during input-family handoff, and the glyphs hide in keyboard/mouse presentation without substituting keyboard shortcuts.

## Role-name presentation

`RolePanel` currently renders the role ID abbreviation in `Header/Label` and the full role name in `Content/RoleName` at the same time, causing the overlap visible in expanded and collapsed headers.

The two labels become mutually exclusive:

- Collapsed role panel: show only the uppercase abbreviated role ID.
- Expanded role panel: show only the uppercase full role name.

The swap occurs synchronously when expansion state changes, before any width animation begins. No frame may render both labels together. The label not in use is hidden rather than merely faded, so it cannot overlap, receive layout space, or remain visible beneath another label.

## XP presentation

Hero XP remains a single hero-wide spendable pool.

### Hero card

The existing HP row becomes a two-sided summary row:

- HP is left-aligned.
- XP is right-aligned.
- The gap between them is created by horizontal expansion, not fixed spaces.

HP retains its existing exact padded presentation. XP uses adaptive shorthand:

- `0–9,999`: exact comma-formatted value.
- `10,000–99,949`: one decimal in thousands, such as `10.0K` or `47.3K`.
- `99,950–999,999`: whole thousands, such as `100K` or `200K`.
- `1,000,000+`: one decimal in millions, such as `1.2M`.

The label includes the `XP` identifier and must fit both desktop and compact hero-card widths without reducing the existing HP readability. Hero XP refreshes after setup and after a successful progression purchase.

### Expanded role header

The expanded role panel retains an exact comma-formatted readout labeled `AVAILABLE XP`, for example `AVAILABLE XP 200,000`. This is the authoritative precise value where the player spends XP. It replaces the ambiguous bare `1,000 XP` presentation.

Collapsed role panels do not show XP. The readout updates after every progression refresh and remains independent of the selected role's own progression.

## Component responsibilities

### `PartyMenu`

- Routes `hub_tab_previous` and `hub_tab_next` from L1/R1.
- Treats Roles content Back as delegated unwinding: `TREE` → `ROLE_SELECT` before `ROLE_SELECT` → hero rail.
- Enters Roles through the role-selection default rather than a tree node.
- Preserves existing Items and stub-tab behavior.

### `SkillTreePanel`

- Owns the `ROLE_SELECT` and `TREE` sub-depth state.
- Exposes deterministic entry, Back unwinding, and focus restoration methods to `PartyMenu`.
- Makes role panels focusable targets at role-selection depth.
- Uses spatial Left/Right for role selection and Confirm/Down for tree entry.
- Routes L2/R2 to supported rank pages only at tree depth.
- Publishes hints appropriate to the active sub-depth.

### `RolePanel`

- Exposes a focusable role-selection surface without making generated tree nodes active at the wrong depth.
- Swaps abbreviated and full role labels synchronously with expansion.
- Shows exact `AVAILABLE XP` only while expanded.
- Removes the former role-switch shoulder glyphs from its upper content area.

### `HeroPanel`

- Formats and displays abbreviated XP beside HP.
- Refreshes both HP and XP from the current hero data.
- Keeps the row readable in desktop and compact layouts.

### Input and glyph maps

- `hub_tab_previous` / `hub_tab_next` map to L1/R1.
- New `hub_page_previous` / `hub_page_next` actions map to L2/R2. The obsolete `hub_role_previous` / `hub_role_next` actions are removed after every call site, glyph, hint, and test moves to spatial role selection or the new page actions.
- Trigger input uses the existing press/release hysteresis so one physical pull changes exactly one page.

## Invalid and changing state

- A hero with no rendered roles cannot enter Roles content and remains on the hero rail.
- A role with no generated nodes remains selectable, but tree entry fails safely and retains role focus.
- If a remembered role disappears, role selection falls back to the first rendered role.
- If a remembered page is unsupported, it resolves through the existing closest-supported-page rule.
- If a remembered node disappears, tree entry uses the existing nearest deterministic node.
- Switching top-level tabs while in `TREE` stores the tree context. Returning to Roles begins at `ROLE_SELECT` for that context.
- Pointer selection and controller focus update the same selected role and stable memory.
- Nested modal ownership continues to block underlying hub actions while still allowing analog trigger releases to rearm.

## Automated verification

Regression coverage protects:

- collapsed roles show only abbreviations and expanded roles show only full names;
- no role-name overlap exists before, during, or after expansion changes;
- Roles entry focuses the remembered role panel rather than a generated node;
- Left/Right changes roles only at `ROLE_SELECT`;
- Confirm/Down enters the selected tree and restores its stable node;
- Back unwinds `TREE` → `ROLE_SELECT` → hero rail → close;
- L1/R1 change top tabs and no longer change roles;
- L2/R2 change only supported rank pages and require trigger release before another change;
- rank-page trigger glyphs resolve for every controller family and hide in keyboard/mouse mode;
- hero XP formatting at `0`, `9,999`, `10,000`, `99,949`, `99,950`, `200,000`, and `1,000,000`;
- hero HP/XP alignment and bounds at `1920x1080` and `1280x800`;
- expanded role exact `AVAILABLE XP` refresh after a purchase;
- collapsed roles never show the XP readout; and
- existing Items navigation and nested Back behavior remain unchanged.

Final verification runs focused hub progression, input-map, glyph, focus, and responsive-layout tests, followed by the complete isolated-`HOME` GUT suite. Visual controller feel and exact alignment remain manual acceptance items.

## Manual acceptance

At both supported viewport sizes, verify:

- collapsed and expanded role headers never overlap;
- role selection is visually distinct from tree-node focus;
- Left/Right role selection feels spatial and predictable;
- Back always moves outward by exactly one conceptual level;
- top L1/R1 and lower L2/R2 glyph placement communicates hierarchy immediately;
- page glyphs do not cause layout movement during input-family handoff;
- HP and abbreviated XP scan cleanly on all hero cards;
- exact `AVAILABLE XP` remains readable for at least six-digit values;
- a progression purchase updates both XP readouts immediately; and
- mouse/touch direct selection still synchronizes the controller restoration context.
