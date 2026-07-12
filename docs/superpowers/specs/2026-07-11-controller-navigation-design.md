# Controller and Steam Deck Navigation Design

## Purpose

Make the complete playable loop usable with a controller or Steam Deck without requiring a mouse or touchscreen, while preserving seamless mouse, keyboard, and touch interaction.

The design uses semantic input actions and screen-specific navigation adapters. A persistent custom visual cursor follows the mouse freely or snaps to semantic controller focus, but it does not simulate or warp the operating-system pointer.

## Scope

The first controller milestone covers:

- Title screen and ordinary menus.
- Hub hero selection, inventory, equipment, role trees, and skill nodes.
- Dungeon-map movement, scan targeting, camera pan, zoom, and recenter.
- Terminal options and result/modals.
- Battle hero selection, direct skill activation, and target selection.
- Runtime device detection and glyph-family switching.
- Keyboard/mouse prompts through the same semantic action model.
- Steam Deck readability and complete controller-only traversal.

The milestone does not include:

- A player-facing rebinding screen.
- Steam Input API integration beyond standard Godot joypad events and controller-name detection.
- Multiplayer controller assignment.
- Skill-purchase draft/confirm mode.
- Console certification work beyond following platform conventions and using appropriate prompts.

## Semantic Input Layer

Gameplay and UI code consume semantic Input Map actions rather than raw keys, button indexes, or device-specific labels.

Required actions include:

- `nav_up`, `nav_down`, `nav_left`, `nav_right`
- `confirm`, `cancel`
- `page_previous`, `page_next`
- `section_previous`, `section_next`
- `action_1`, `action_2`, `action_3`, `action_4`
- `shift_action`
- `camera_pan_left`, `camera_pan_right`, `camera_pan_up`, `camera_pan_down`
- `zoom_in`, `zoom_out`
- `recenter`
- `refund_progression` reserved for a future progression-reset feature

`InputManager` owns:

- Active presentation mode: keyboard/mouse or controller.
- Active controller family.
- Meaningful mouse-motion threshold.
- Stick deadzones and directional-repeat timing.
- Device connection/disconnection handling.
- Mode-change and controller-family-change signals.

Raw controller events outside this layer are prohibited except in focused low-level input tests.

No remapping screen is implemented, but the semantic boundary must allow future runtime rebinding without changing screen logic.

## Device Detection and Platform Conventions

Supported glyph families are:

- Keyboard/mouse.
- Xbox.
- PlayStation.
- Nintendo Switch.
- Nintendo Switch 2.
- Steam Controller.
- Steam Deck.

Unknown or unrecognized controllers fall back to Steam Deck-style prompts. These retain the familiar Xbox-compatible A/B/X/Y layout while making Steam the default presentation for the game's primary PC and handheld target. Recognized Steam virtual-controller names also prefer Steam Deck prompts when distinguishable.

Platform conventions govern confirm/cancel:

- Xbox and Steam: A confirms, B cancels.
- PlayStation: Cross confirms, Circle cancels.
- Nintendo: A/right confirms, B/bottom cancels.

The semantic meaning remains `confirm` and `cancel`; device mappings and glyphs provide the platform-specific physical buttons.

Mouse movement beyond a small threshold or meaningful keyboard input switches to keyboard/mouse mode. Tiny sensor/jitter movement does not steal the active mode. Any meaningful controller input switches immediately to controller mode.

## Curated Input Glyphs

Runtime glyphs live under lowercase snake_case paths:

```text
assets/graphics/glyphs/
  keyboard_mouse/vector/
  nintendo_switch/vector/
  nintendo_switch_2/vector/
  playstation/vector/
  steam_controller/vector/
  steam_deck/vector/
  xbox/vector/
```

Only selected SVG assets are retained. Duplicate PNG sizes, outline variants, fonts, XML sheets, and atlases are excluded. Godot generates fresh `.import` files from the normalized paths.

The semantic glyph resolver maps actions to textures. Screens never preload device-family file paths directly.

`DynamicGlyph` subscribes to active-mode/family changes and safely handles missing mappings. The deleted legacy `glyphs/ps/...` preloads are removed first so the project can start before subsequent navigation work.

Keyboard prompts use retained key SVGs for common keys. A future rebindable-character implementation can render text over a blank key asset.

Prompts follow Kenney's guidance: short labels, visual breathing room, high contrast, and minimal text.

## Persistent Custom Cursor

The game displays an in-game `NavigationCursor` continuously.

It never warps the OS pointer. Its target source changes by input mode:

- Keyboard/mouse mode: follows the real pointer freely.
- Keyboard/controller mode: snaps or tweens to the active semantic focus target.
- Dungeon targeting: follows the selected map-node reticle.

Every focusable screen element can expose a cursor anchor. The default anchor is the control center; individual controls may override it.

The cursor uses semantic states:

- `DEFAULT`: outlined `pointer_c`.
- `INTERACT`: outlined `hand_point`.
- `CAN_GRAB`: outlined `hand_open`.
- `DRAGGING`: outlined `hand_closed`.
- `UPGRADE`: outlined `tool_hammer`.
- `DISABLED`: outlined `cursor_disabled`.
- `BUSY`: outlined `busy_circle`.
- `TARGET`: outlined `cross_small`.
- `MODIFY`: outlined `cursor_cogs`.

Equipment pickup/drop uses open/closed hand states. Compatible and incompatible drop targets combine cursor state with a valid/invalid glow. Upgrade/tune screens use the hammer state.

Cursor state is requested semantically through an interface or metadata; controls do not reference cursor textures directly.

Focused controls receive only a subtle scale treatment alongside the custom cursor. The global navigation layer does not replace or add a focus border/glow, so authored button, owned, affordable, disabled, selected, and hovered styling remains untouched.

## Contextual Hint Bar

Screens publish currently available semantic actions and short labels, for example:

```text
Confirm        Accept
Cancel         Back
Refund         Refund XP
Page Previous  Previous Page
Page Next      Next Page
```

In controller mode the hint bar renders the appropriate glyph family immediately. In keyboard/mouse mode the non-clickable hint bar hides entirely, while actual clickable UI controls remain visible.

Hint availability reacts to state. An unavailable action is omitted or visibly disabled rather than showing a misleading active prompt.

## Ordinary Menus, Terminals, and Modals

Title screens, terminal choices, result screens, and standard lists use Godot focus with explicit neighbors where automatic ordering is ambiguous.

Rules:

- Opening a screen focuses a safe, deterministic default.
- Closing a nested screen restores the prior focus target when valid.
- Modals trap focus until dismissed.
- Disabled/hidden controls cannot receive focus.
- Focus never becomes null while a controller-navigable screen is active.
- Cancel follows the screen's hierarchy instead of closing multiple layers at once.

## Hub Navigation

The hub uses a layered focus hierarchy.

Skill screen bindings:

- L1/R1: previous/next rank page (inner navigation).
- L2/R2: previous/next role tree (outer navigation).
- L2/R2 always switch roles while the skill screen is open, regardless of focus depth.
- D-pad/left stick: navigate within the current focus layer.
- Confirm: activate or purchase.
- Cancel: move outward toward hero selection, then close/back from the hero list.

Hero selection uses Up/Down after backing out to the hero list. Entering a hero restores that hero's last role, page, and stable focused node ID when still valid.

Skill-tree nodes use geometric navigation rather than a manually authored focus graph:

- Candidate nodes come from the current visible page.
- Directional selection uses node screen positions derived from explicit rank/column data.
- The chosen node must be in the requested directional half-plane.
- Candidates are scored by angular alignment first and distance second.
- Locked nodes remain focusable for inspection but cannot purchase.
- Changing page chooses the nearest sensible node and never leaves focus null.
- Changing role restores the role's last focused node when valid.

Inventory/equipment grids use ordinary focus navigation plus semantic cursor states for pickup, drag, valid drop, invalid drop, tune, and modification.

## Dungeon Map Navigation

The dungeon map uses angular neighbor snapping from the current node.

- Left stick/D-pad selects eligible neighboring nodes.
- Crossing the deadzone immediately snaps to the neighbor closest to the input angle.
- The preview target remains selected when the stick returns to neutral.
- Confirm invokes the same validated movement path used by mouse clicks.
- Cancel clears a preview or cancels scan targeting.
- Hidden, invalid, completed, and unreachable nodes are excluded according to existing map rules.
- Scan targeting uses the same directional selector over scan-eligible candidates.

Camera controls:

- Right stick pans continuously with deadzone and frame-rate-independent speed.
- L2/R2 zoom out/in on the map.
- Right-stick press recenters on the current node.
- Camera input is disabled during loading/locked states and respects existing clamps.

The custom cursor/reticle snaps to the preview node. The player cursor remains on the current node until movement is confirmed.

## Battle Navigation

Combat skill selection does not use cursor traversal through the action bar.

- Four action slots map directly to the four face-button semantic actions.
- Each action displays its active device glyph.
- Disabled or unaffordable actions disable/dim their glyph and button consistently.
- Mouse users may click actions directly.
- The persistent cursor remains on the active hero/target selection area when a controller face button is pressed.

After choosing an action:

- D-pad/left stick navigates valid hero or enemy targets.
- The cursor snaps to the focused target card.
- Confirm completes a target choice when required.
- Cancel exits targeting and returns to action selection.
- Existing battle validation and action execution remain authoritative.

Shift action uses its dedicated semantic binding and glyph.

## Focus Memory and Screen Adapters

One global `NavigationUXLayer` lives above screen content near the root viewport. It owns cursor presentation, focus scaling, action hints, active-device presentation, modal focus trapping, and focus restoration. Ordinary Godot controls work through standard focus plus metadata or registration, so each screen does not recreate controller UX.

The shared input foundation owns device mode, repeat/deadzone behavior, and glyph resolution. The UX layer consumes that state and presents it consistently across every screen.

Complex screens implement thin adapters only where the UX layer cannot infer gameplay meaning. Skill trees provide geometric node selection, the dungeon provides eligible angular neighbors and camera actions, battle provides direct action slots and valid targets, and inventory provides valid pickup/drop rules. These adapters expose:

- Current focus target.
- Directional movement request.
- Confirm/cancel behavior.
- Available hints.
- Cursor anchor and semantic cursor state.
- Focus restoration key.

Stable content IDs are used for restoration where available, especially progression node IDs and map coordinates. Scene-instance references are never persisted across scene replacement.

## Accessibility and Steam Deck Requirements

- Focus is always visible with adequate contrast.
- Focus does not rely only on color.
- Stick deadzones prevent drift.
- Directional repeat has an initial delay and predictable repeat rate.
- Controller prompts update immediately after device changes.
- Text and glyphs remain readable at Steam Deck resolution.
- Every playable screen is completable without touchscreen or mouse.
- Touch/mouse controls remain functional and switching devices does not reset gameplay state.

## Testing and Verification

Automated coverage includes:

- Controller-name to glyph-family detection, including fallbacks.
- Platform confirm/cancel conventions.
- Mouse jitter threshold and mode switching.
- Semantic action-to-glyph resolution with no missing retained assets.
- Dynamic glyph updates and missing-map safety.
- Cursor state, anchor, snap, tween completion, and mode transitions.
- Hint availability and device-family updates.
- Focus restoration and disabled/hidden exclusion.
- Skill-tree geometric navigation, page/role bindings, and stable-ID restoration.
- Dungeon angular selection, eligibility filtering, retained preview, confirm/cancel, pan/zoom/recenter, and lock-state suppression.
- Battle face-button skill activation and target navigation.
- Controller-only integration paths for title → hub → dungeon → terminal → battle → result → hub.
- Mouse/controller switching within each complex screen.

Manual verification covers Xbox, PlayStation, Nintendo, and Steam Deck/Steam Input devices where hardware is available, plus keyboard/mouse coexistence.

## Implementation Sequence

1. Normalize/commit curated assets and remove generated repository noise.
2. Repair `dynamic_glyph.gd` and introduce semantic glyph resolution.
3. Add semantic Input Map actions, device modes, and platform mappings.
4. Add persistent cursor, semantic cursor states, focus scaling, and hint bar.
5. Convert ordinary menus, terminals, and modals.
6. Implement hub hierarchy and geometric skill-tree navigation.
7. Implement dungeon angular navigation and camera controls.
8. Complete battle face-button/target navigation.
9. Run full automated and hardware/manual controller verification.
