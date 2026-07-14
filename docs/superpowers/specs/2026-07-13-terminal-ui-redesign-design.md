# Terminal UI Redesign

## Goal

Redesign the dungeon terminal as a large, readable command-line interface that remains visually distinctive while working comfortably at Steam Deck scale. The redesign improves presentation and input handling without changing terminal gameplay effects, upgrade rules, scan behavior, extraction rewards, or saved data.

The minimum acceptance viewport is 1200×800. Steam Deck's native 1280×800 resolution is covered by that stricter horizontal target.

## Existing Problems

The current terminal is a fixed 680×640 control positioned with fixed offsets inside a 1920×1080 canvas. Its 22-point RichTextLabel content becomes too small at handheld resolution. All five choices are embedded RichText links, controller focus defaults to the close button, and the visual rows are not actual UI controls.

The current interaction also divides responsibility between clickable RichText links and hard-coded action-slot handling. Extraction does not have a dedicated controller shortcut or a deliberate confirmation state.

## Visual Direction

The terminal keeps its command-line identity. It does not become a conventional card menu.

The modal panel occupies approximately 90–91% of the available viewport width and height, centered with proportional outer margins. A small amount of the dungeon remains visible around it so the terminal reads as an in-world modal rather than a separate scene.

The terminal retains its warm orange/brown palette, monospace typography, bright header strip, border glow, session metadata, and trace warning. The redesign does not enable the currently disabled CRT overlay; that shader remains available for later visual tuning. The layout establishes three clear regions:

1. a header with terminal identity, facility name, and clickable close control;
2. a body containing authentication status and the five protocol rows;
3. a footer containing security flavor text and contextual input guidance where useful.

At 1200×800, normal protocol text must render at approximately 22–24 physical pixels or larger. Metadata and footer text may be smaller but must remain legible. The implementation uses proportional anchors and margins instead of the current fixed root offsets. Font sizes and row spacing are verified at both 1200×800 and 1920×1080.

## Protocol Controls

Each protocol becomes a real clickable/focusable control styled as a line of terminal output. The controls have no conventional button chrome. Hover or focus uses terminal-native presentation such as a leading caret, inset bar, thin outline, or restrained glow.

The terminal builds its presentation from structured local protocol definitions. Each definition supplies:

- the existing emitted choice ID;
- its normal or upgraded label;
- its outcome summary;
- its semantic input action;
- whether the upgraded form is active.

The existing `option_selected(choice_id)` and `closed` signal contracts remain authoritative. GameManager continues to apply the selected protocol, complete or preserve the node, and route scan or extraction outcomes.

## Direct Input Scheme

Directional navigation is available as a fallback through the real controls, but direct hotkeys are the primary terminal interaction.

| Protocol | Keyboard | Controller |
| --- | --- | --- |
| Security | 1 | Cross/A/confirm-position face button |
| Scan | 2 | L1/LB/left shoulder |
| Medical | 3 | Square/X/left face button |
| Finance | 4 | Triangle/Y/top face button |
| Extraction | 5 | R1/RB/right shoulder |
| Back/Close | Escape | Circle/B/cancel-position face button |

Controller labels resolve through the existing semantic glyph system. PlayStation displays Cross, L1, Square, Triangle, R1, and Circle for Back. Xbox and Steam-compatible families display A, LB, X, Y, RB, and B for Back. Nintendo displays A, L, Y, X, R, and B for Back. Keyboard-and-mouse displays 1–5 and Escape.

The five protocols receive terminal-specific semantic actions rather than borrowing combat action slots. The Security action follows the active controller family's confirm-position binding so Nintendo retains A as Security and B as Back. Extraction uses a dedicated semantic action rather than borrowing an unrelated screen action merely because it shares the same shoulder.

Mouse users can click any protocol row. Protocols 1–4 execute immediately. Clicking Extraction enters the same guarded state as its keyboard or controller shortcut.

The terminal does not publish a redundant global action-hint bar while open. Its embedded glyphs, clickable rows, close control, and extraction confirmation contain all required guidance.

## Interaction State Model

Terminal owns four explicit states:

### Typing

The terminal opens with its brief typewriter animation. The first protocol action, Confirm press, or click during this animation completes the text immediately and consumes that input. It never also activates a protocol. Cancel may close the terminal immediately.

### Ready

Protocols 1–4 execute their existing choice immediately. Extraction enters the guarded confirmation state. The existing one-shot interaction guard prevents repeated signals while the close animation or downstream interaction is underway.

### Confirming Extraction

The normal protocol rows become visibly inactive and their shortcuts are ignored. The terminal displays an unmistakable warning that extraction abandons the current run and uses tactical-retreat reward rules.

Confirm accepts extraction and emits the existing extraction choice exactly once. Cancel returns to Ready without closing the terminal or consuming the node. Mouse users receive explicit clickable Confirm and Cancel controls with the same behavior.

This confirmation is intentionally unique to Extraction. Requiring confirmation for every protocol would train players to double-tap automatically and weaken the safety value of the extraction warning.

### Closing

All actionable inputs are disabled. The existing close animation finishes once, then the terminal either emits `closed` or leaves through the selected protocol path. Repeated clicks or input events cannot emit a second outcome.

Calling `setup()` on a reused terminal resets the typewriter animation, confirmation state, visibility, close state, protocol controls, and one-shot guards.

## Focus and Modal Ownership

When the terminal opens, the first available protocol is the default focus target rather than the close button. The close button remains clickable.

The terminal continues to own the top modal through NavigationUXLayer. Normal Cancel closes it. Cancel during extraction confirmation only returns to the protocol list. Closing or completing a terminal restores the live dungeon-map adapter, cursor ownership, reticle state, and map hints through the existing modal lifecycle.

Input family and controller glyph family continue to come from the global InputManager autoload. Opening or reopening a terminal must immediately render the currently active family without waiting for another local input.

## Failure Handling

DungeonSaveCodec and GameManager remain responsible for rejecting malformed terminal payloads before presentation. Terminal still treats its setup input defensively:

- an unrecognized or incomplete protocol definition does not create an actionable row;
- a missing glyph does not prevent mouse or fallback focus activation and does not crash the modal;
- a missing NavigationUXLayer leaves mouse interaction and safe closing available;
- repeated selections, close requests, and extraction confirmations are idempotent;
- teardown disconnects or discards modal ownership without restoring focus into a scene that is exiting.

No fallback path silently selects a different protocol.

## Automated Verification

Automated tests cover:

- panel bounds, minimum readable layout, and absence of clipping at 1200×800 and 1920×1080;
- correct keyboard, PlayStation, Xbox/Steam, and Nintendo glyph resolution;
- the controller mapping remaining Cross/A for Security, L1/LB for Scan, Square/X for Medical, Triangle/Y for Finance, R1/RB for Extraction, and Circle/B for Back;
- protocols 1–4 emitting their existing choice IDs exactly once from keyboard, controller, focus activation, and mouse activation;
- keyboard 5 and the controller right shoulder entering extraction confirmation without emitting a choice;
- Confirm emitting extraction exactly once and Cancel returning to Ready;
- ordinary protocol shortcuts being ignored while extraction confirmation is open;
- the first actionable input during Typing only completing the animation;
- normal Cancel closing the terminal and restoring the map adapter;
- scan cancellation reopening the terminal with fresh typing, confirmation, controls, and one-shot state;
- active input mode and glyph family carrying into the terminal before any terminal-local input;
- malformed or missing presentation data failing safely without an actionable broken row.

Tests assert stable state transitions, signal counts, semantic mappings, focus ownership, and layout bounds rather than animation timing or pixel-perfect styling.

## Manual Acceptance

Manual verification covers:

- readability, spacing, focus visibility, and absence of clipping at 1200×800, 1280×800, and 1920×1080;
- typewriter timing and instant completion by controller, keyboard, and mouse;
- all keyboard, DualSense, mouse, and controller-family glyph interactions;
- immediate protocols versus guarded extraction confirmation;
- controller-family switching while the terminal is open;
- terminal close, protocol completion, scan cancellation/reopen, and map focus restoration.

## Out of Scope

- Changing protocol effects, values, upgrades, or availability.
- Changing scan targeting or camera behavior.
- Changing extraction rewards or run-end routing.
- Changing terminal payload or save formats.
- Introducing new terminal protocols or dungeon content.
- Building a general custom terminal renderer.
- Broadly refactoring typed dungeon interaction payloads; that remains tracked separately in `docs/refactor.md`.
