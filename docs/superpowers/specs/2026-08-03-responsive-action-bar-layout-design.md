# Responsive Action Bar Layout Design

## Status

Approved for implementation on 2026-08-03.

## Summary

Replace the battle action bar's hand-positioned plus-shaped controls with a bottom-centered, container-driven row:

`[Shift Left] [Ability 1] [Ability 2] [Ability 3] [Ability 4] [Shift Right]`

The role passive and Shift Action remain above the command row as subdued bookends around the separately authored hero lane. This change is limited to action-bar layout and the script references required by the new node hierarchy. The user's compact hero-card work remains separate and untouched.

## Goals

- Keep all four abilities in one readable horizontal row.
- Make the row responsive through Godot containers instead of per-control anchors and offsets.
- Preserve direct face-button activation, left/right shift input, action order, tooltips, costs, disabled state, and animation behavior.
- Fit the supported `1920x1080` and `1280x800` outputs without overlapping the right-side turn queue.
- Retain large, comfortable interaction targets while allowing the visible panels to appear slightly slimmer.

## Scene Structure

`ActionBar` remains the public scene and script class. Its presentation hierarchy becomes:

```text
ActionBar
├── TopRow (HBoxContainer)
│   ├── Passive
│   ├── Spacer (expands across the separately authored hero lane)
│   └── ShiftAction
└── BottomRow (HBoxContainer)
    ├── LeftShift
    ├── Actions (HBoxContainer)
    │   ├── ActionButtonD  (action_1)
    │   ├── ActionButtonR  (action_2)
    │   ├── ActionButtonL  (action_3)
    │   └── ActionButtonU  (action_4)
    └── RightShift
```

`BottomRow` is centered inside a bottom-wide action-bar root. `Actions` distributes the four ability controls evenly in `D`, `R`, `L`, `U` order, matching `action_1` through `action_4` and the order in which abilities are learned. The shift endcaps use smaller width allocations than abilities. Container separation, margins, size flags, and stretch ratios determine placement; the six controls do not receive individual horizontal anchors.

Each action-button component is `270x100` logical pixels and reports its complete visual footprint to its parent container. Its dynamic controller glyph occupies the upper portion inside those bounds; its `270x70` visible action panel sits at the bottom. No glyph draws outside the component bounds, so the HBox and hero-lane spacing need no special overflow calculation.

The left and right role-shift controls are `220x70` logical pixels and belong to `BottomRow`. Passive and Shift Action are `270x70` panels owned by `TopRow`; an expanding center spacer keeps them as upper bookends without placing them in the four-ability `Actions` container. They retain their existing behavior and do not consume command-row width.

## Responsive Policy

The project renders a `1920x1080` reference UI with `canvas_items` stretch and `expand` aspect handling. At `1280x800`, the logical width remains sufficient for a bounded reference-width command row and the complete UI scales uniformly. The action bar therefore does not implement arbitrary per-button shrinking.

Containers absorb available width within the bounded row. Text truncates before controls overlap. The complete `100`-pixel action-button component becomes approximately 67 physical pixels tall at `1280x800`, preserving the compact physical-size requirement. Supporting substantially smaller windows than `1280x800` is outside this change.

## Script Boundary

`ActionBar.actions_ui` continues to refer to a node whose first four children are the four `ActionButton` instances in logical slot order. Existing index-based activation therefore remains valid for production code and lightweight test fixtures.

Scene-owned references change from incidental child placement to explicit paths:

- `actions_ui` resolves the nested `Actions` container;
- left and right shift controls resolve their nodes inside `BottomRow`;
- passive and Shift Action resolve their nodes inside `TopRow`;
- responsive sizing and shift-glyph lookups use those stored references rather than repeated string paths.

The public signals and methods remain unchanged, including `activate_slot`, `activate_shift`, `load_actions`, `action_selected`, and `shift_button_pressed`.

## Animation

The complete `BottomRow` enters and exits as one horizontal command unit. Passive and Shift Action presentation retains its existing flash behavior. The redesign removes the current independent left/right fly-in geometry that depends on manually recorded positions.

Animation never changes container layout properties. It animates a presentation wrapper or non-layout transform so the HBox remains authoritative and controls return to exact container positions.

## Missing Content and Availability

- A missing neighboring role hides its shift endcap without disturbing ability order.
- A missing action hides its corresponding logical slot according to existing behavior.
- A missing passive or Shift Action hides only that upper panel.
- Disabled and unaffordable controls retain their existing behavior and glyph dimming.
- Missing icons preserve readable titles and dynamic controller glyphs.

## Verification

Automated tests cover:

- the packed scene's exact command order;
- four equal-width ability controls and narrower shift endcaps;
- container ownership rather than hand-authored per-button positions;
- fit at `1920x1080` and `1280x800`;
- no overlap with the turn queue;
- minimum compact physical height;
- unchanged `action_1` through `action_4` activation;
- unchanged left and right role-shift activation;
- hidden shift endcaps and missing action slots preserving layout and mapping;
- slide-in and slide-out restoring exact container-owned geometry.

Implementation runs focused action-bar, responsive-layout, and controller-navigation tests first, then the complete isolated Godot/GUT suite. Manual acceptance verifies mouse and controller interaction at both target outputs, including tooltips, focus/selection presentation, rapid hero turns, shifts, and targeting cancellation.

## Non-goals

- Further hero-card layout changes.
- Enemy formation or camera changes.
- Turn-queue redesign.
- New controller mappings.
- Touch-specific behavior.
- Supporting output sizes below the current `1280x800` compact target.
