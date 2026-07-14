# Input Ownership and Focus Presentation Design

## Summary

Replace cursor-snapped controller navigation with an explicit separation between input ownership and navigation presentation. Ordinary controller navigation hides the physical mouse cursor and presents selection through a strong, color-agnostic focus fill. Keyboard and mouse handoffs preserve an independent physical mouse position, and no ordinary navigation path warps it.

The existing styled arrow becomes a hardware-positioned custom cursor. A software cursor remains only for controller interactions that genuinely need a freely positioned pointer, currently security-terminal scan targeting.

## Goals

- Hide the hardware mouse cursor during ordinary controller use.
- Keep physical mouse motion from taking ownership away from the controller.
- Restore keyboard-and-mouse ownership on a keyboard press or physical mouse click.
- Let a keyboard handoff perform its intended action immediately.
- Consume the first physical mouse click used to leave controller mode so an invisible pointer cannot activate a control accidentally.
- Preserve logical GUI focus while mouse hover temporarily owns presentation.
- Replace the focus scale animation and snapped arrow with a clear, consistent focus fill.
- Keep controller scan targeting usable without coupling its software pointer to the physical mouse.
- Eliminate physical mouse warping from navigation.

## Non-goals

- Redesigning control layouts, navigation graphs, map traversal rules, battle targeting rules, or scan gameplay.
- Changing controller bindings, glyph families, or semantic actions.
- Reworking the controls hint bar in this effort.
- Adding cursor fades, idle timers, or automatic ownership changes based on elapsed time.

## State model

Input state has two independent axes.

### Input owner

- `KEYBOARD_MOUSE` means keyboard and physical mouse input own the conventional desktop presentation.
- `CONTROLLER` means controller input owns navigation and the hardware cursor is hidden.

### Presentation owner

- `POINTER` means mouse hover owns visible GUI feedback. Logical GUI focus remains retained but is not painted.
- `FOCUS` means retained GUI focus owns visible feedback through the shared focus treatment.

Separating these axes avoids using cursor position as navigation state. It also allows keyboard input to reveal the physical pointer while continuing from the same logical focus that controller input used.

The initial state is `KEYBOARD_MOUSE` plus `POINTER`, with the styled hardware cursor visible.

## Input transitions

### Controller input

A meaningful controller button or axis event switches to `CONTROLLER` plus `FOCUS`, hides the hardware cursor, resolves a valid logical focus, and performs the event immediately.

When controller input follows pointer presentation and retained focus is valid, the first directional event moves from that retained focus immediately. It is not consumed as a presentation-only handoff.

Controller-axis values below the existing dead-zone threshold do not change either state.

### Keyboard input

A pressed, non-echo keyboard event switches to `KEYBOARD_MOUSE`, reveals the hardware cursor at its unchanged physical position, and otherwise performs normally.

Keyboard input following controller focus uses the same retained logical focus. Directional input performs its movement immediately; confirm, cancel, shortcuts, and other actions also execute immediately.

Directional keyboard input following mouse pointer presentation behaves differently. The first arrow or WASD navigation press switches to `FOCUS`, restores the retained focus visually, and is consumed without moving. A subsequent navigation press moves from that retained focus. This prevents a mouse hover elsewhere from silently changing the keyboard navigation origin.

Non-navigation keyboard input is never consumed solely to change presentation.

### Mouse motion

Mouse motion in `CONTROLLER` mode does nothing: it does not change input ownership, move the software controller pointer, reveal the hardware cursor, alter logical focus, or affect scan selection.

Mouse motion in `KEYBOARD_MOUSE` mode switches presentation to `POINTER`. It quietly removes the focus fill without releasing or replacing logical GUI focus. Native hover presentation follows the physical pointer. Hovering another control does not change the retained keyboard/controller focus.

While presentation remains `FOCUS`, hover-only feedback is suppressed even when keyboard ownership makes the hardware cursor visible. The pointer's stale position therefore cannot paint a second highlighted control. Actual mouse motion switches to `POINTER` and enables hover feedback at the new physical position.

### Mouse click

A physical mouse-button press in `CONTROLLER` mode switches to `KEYBOARD_MOUSE` plus `POINTER` and reveals the hardware cursor at its independent physical position. The complete initiating click transaction, including the matching release, is consumed so the handoff cannot activate a GUI control, map target, battle target, modal action, or scan target.

Once pointer ownership is active, subsequent mouse clicks behave normally.

## Cursor presentation

The existing styled arrow is installed as Godot's custom hardware cursor with the correct hotspot. Godot and the operating system alone update its position from physical mouse movement.

`InputManager` is the sole owner of ordinary cursor visibility. Navigation controls, screens, adapters, and focus code do not set mouse mode or request a physical warp.

The software navigation cursor is narrowed to the exceptional controller pointer used during security scan targeting. It can be shown at an explicitly supplied screen position and hidden, but it no longer:

- targets focused GUI controls;
- targets world objects;
- selects a cursor-state icon for ordinary navigation;
- follows the physical pointer;
- requests or deduplicates physical mouse warps; or
- changes hardware mouse visibility independently.

Controller scan targeting keeps the hardware cursor hidden and projects the stored controller world aim to the software cursor. Mouse motion remains inert until a click handoff. A click handoff hides the software cursor, reveals the hardware cursor at its unchanged physical position, and consumes the initiating click.

## Focus presentation

Logical focus remains authoritative for controller and keyboard navigation. `NavigationUXLayer` continues to retain, validate, restore, and trap that focus across screens and modal stacks, but only paints it while presentation ownership is `FOCUS`.

The shared `NavigationFocus` treatment changes from a 1.03 scale tween to a color-agnostic selected state:

- approximately 70% opaque white fill;
- dark foreground text or icons where needed for contrast;
- the control's existing shape, border, and screen-specific palette remain recognizable;
- no size change or cursor icon accompanies focus.

Mouse hover retains the existing lighter translucent treatment. Focus and hover therefore use the same neutral visual language, while focus is substantially stronger and readable at controller distance. The 70% focus state remains visibly distinct from the fully white pressed state.

The shared treatment applies to ordinary buttons and button-like hub controls. Purpose-built world selection retains its existing semantic presentation:

- dungeon navigation uses its map reticle;
- battle targeting uses actor-card hover/selection highlighting; and
- controller scanning uses its scan pointer and snapped hex reticle.

Cursor-state metadata used only to select the former snapped-pointer icons is removed with that dead behavior.

## Component responsibilities

### `InputManager`

- Owns input owner and presentation owner.
- Classifies meaningful controller, keyboard, mouse-motion, and mouse-button events.
- Emits state changes for navigation presentation and glyph consumers.
- Controls hardware cursor visibility.
- Tracks and consumes a controller-to-mouse handoff click through its matching release.
- Exposes whether a directional keyboard event is the presentation-restoring press that must not navigate.
- Does not store expected warp positions or warp-suppression deadlines.

### `NavigationUXLayer`

- Retains logical focus independently of visible focus presentation.
- Applies or clears `NavigationFocus` when presentation ownership changes.
- Enables hover-only presentation in `POINTER` and suppresses it in `FOCUS`, preventing simultaneous authoritative highlights.
- Restores a valid modal or screen fallback before painting focus when the retained target is invalid.
- Stops assigning focused controls to a navigation cursor.
- Preserves existing screen registration, modal trapping, restoration, and hint ownership.

### `NavigationFocus`

- Applies and restores the shared 70% neutral focus presentation.
- Preserves component-authored styles and colors needed when focus clears.
- Supports representative `Button`, `TextureButton`, and button-like controls without scaling them.

### Scan software cursor

- Displays the controller-driven scan position only while scan targeting is active in controller mode.
- Never influences physical pointer position or ordinary GUI focus.
- Hides on scan exit or input handoff.

### Map and battle adapters

- Keep their logical target-selection rules.
- Stop assigning world targets to the former general-purpose navigation cursor.
- Continue using their reticle and actor highlight presentation.

## Invalid and changing focus

Mouse pointer presentation can outlive the control that originally held logical focus. If retained focus becomes hidden, disabled, freed, or leaves the active screen/modal, the next focus-driven input resolves the existing registered fallback before presenting focus.

When pointer presentation has no valid retained focus, the first keyboard navigation press establishes and reveals the fallback without moving beyond it. Controller input also establishes the fallback; an event can move immediately only when there was a valid retained navigation origin.

Modal ownership remains authoritative during every handoff. Pointer presentation must not allow hover or clicks outside the top modal to replace retained modal focus, and focus presentation must not restore into a removed modal or screen.

## Automated verification

Unit coverage protects:

- the complete input-owner and presentation-owner transition matrix;
- ignored mouse motion during controller ownership;
- keyboard handoff with immediate action execution;
- controller handoff with immediate directional movement from valid retained focus;
- the pointer-to-keyboard first-navigation suppression rule;
- full press/release consumption for the first controller-to-mouse click;
- key-echo and controller-axis noise rejection;
- cursor-visibility signals and state changes; and
- removal of expected-warp bookkeeping.

Navigation integration coverage protects:

- logical focus retention while mouse motion hides focus presentation;
- mouse hover on another control without replacing retained focus;
- first keyboard navigation restoring retained focus and the second moving;
- controller direction moving immediately from retained focus;
- controller-to-keyboard direction moving immediately while revealing the hardware cursor;
- invalid retained focus resolving to the active screen or modal fallback;
- modal trapping and restoration across all presentation transitions;
- the 70% focus treatment, dark foreground contrast, and absence of scale animation;
- representative title, hub, terminal, result, skill-node, inventory, and equipment controls; and
- no physical mouse warp requests.

Map and battle integration coverage protects:

- reticle and actor highlighting without world-target cursor assignment;
- controller scan pointer visibility with the hardware cursor hidden;
- independent physical mouse position throughout controller scanning;
- inert physical mouse motion during scanning;
- consumed click handoff that neither confirms a scan nor activates the object beneath the hidden pointer; and
- scan confirmation, cancellation, modal restoration, and camera behavior remaining unchanged.

Because the change crosses global input, navigation, modal, scene, map, battle, and scan behavior, final automated verification runs the complete GUT suite using the repository's mandatory isolated `HOME`.

## Manual verification

Update and run the controller manual checklist across title, hub, dungeon, terminal, battle, and result screens. In addition to existing device-family coverage, verify:

- ordinary controller navigation never shows an arrow on focused controls;
- the 70% neutral focus fill is clear across orange, blue, and neutral screen palettes;
- the hardware cursor stays hidden despite small and large physical mouse movement in controller mode;
- the first mouse click reveals the cursor but activates nothing;
- a second click activates the expected target;
- keyboard input from controller mode reveals the cursor and acts immediately;
- mouse motion in keyboard-and-mouse mode quietly hides focus while retaining its navigation origin;
- the first arrow/WASD press after mouse presentation restores that origin, and the second moves;
- controller direction after mouse presentation hides the cursor and moves immediately;
- rapid alternation never creates two authoritative highlights or stale modal focus; and
- controller scanning retains its software pointer while the physical cursor remains independent.

## Deferred controls-hint cleanup

A separate follow-up should redesign the controls hint bar as a deliberate floating panel. Sentence-case informational copy should use Archivo, consistent with the combat UI. The monospace font should be reserved for uppercase labels and other all-caps interface text. This typography and container cleanup is intentionally outside the input-ownership implementation.
