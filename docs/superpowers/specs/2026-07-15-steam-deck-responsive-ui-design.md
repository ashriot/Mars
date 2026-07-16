# Steam Deck Responsive UI Design

## Purpose

Redshift will support the Steam Deck's native `1280x800` handheld display while preserving the existing `1920x1080` desktop presentation. This is a project-wide resolution and usability target, not a combat-only adjustment. The supported acceptance viewports for this effort are `1280x800` and `1920x1080`; docked displays may benefit from the same responsive system but are not exhaustively certified in this pass.

The implementation will use one responsive scene set. It will not create Steam Deck-specific copies of screens or identify the device through operating-system or hardware strings.

## Current Constraints

The project already uses a `1920x1080` reference viewport with `canvas_items` stretch mode and `expand` aspect handling. That is a useful authoring baseline and already allows a 16:10 window to expose more logical height rather than cropping the 16:9 canvas.

Two current behaviors prevent that foundation from being consistently responsive:

- `project.godot` requests a `1920x1080` runtime window even when the display is smaller.
- `Main` manually scales and centers `WorldLayer` as a fixed `1920x1080` rectangle, while CanvasLayer menus use the engine's expanded viewport. Gameplay and menu scenes therefore follow different resolution policies.

At `1280x800`, a `1920x1080` reference composition scales to roughly two thirds of its authored size. The main risk is consequently physical readability and input-target size, not loss of aspect ratio alone.

## Chosen Approach

Keep `1920x1080` as the authoring reference and retain `canvas_items` plus `expand`. Add a compact handheld display profile and make targeted scene-local adjustments where the scaled desktop presentation becomes too small or dense.

Changing the reference canvas to `1280x800` was rejected because it would disturb nearly every established layout. Separate handheld scenes were rejected because they would duplicate presentation logic and drift as the prototype changes.

## Display Policy

### Runtime profile

A small central display-profile service owns resolution measurement and classification. It reads the actual window size reported by `DisplayServer` and the expanded logical viewport size.

The compact profile is active when either reported window dimension is constrained to the handheld range:

- width is `1366` pixels or less; or
- height is `800` pixels or less.

This includes Steam Deck at `1280x800`, the existing `1200x800` minimum used by terminal acceptance, and similar handheld or small-window conditions. Larger windows use the desktop profile. Resize events with a zero dimension are ignored. The service emits a change only when the profile or meaningful viewport dimensions change; scenes do not poll it every frame.

Responsive scenes receive the current profile when they enter the tree and may implement an `apply_display_profile()` boundary for genuine layout changes. Values remain owned by the scene they describe: battle dimensions remain in battle UI, hub panel dimensions remain in hub UI, and the profile service contains no screen-specific styling.

### Startup window

The forced `1920x1080` window override will be removed. Startup behavior will fit the available display:

- On a display in the compact range, the game uses the available screen size in borderless fullscreen, giving Steam Deck a native `1280x800` output.
- On a larger desktop display, the current `1920x1080` windowed target remains the default.

This policy is based on available dimensions rather than Steam Deck detection. A graphics settings menu and saved resolution preferences are outside this effort.

### World and UI coordinates

The hard-coded scale and centering transform in `Main` will be removed. World scenes and UI scenes will receive one expanded logical viewport.

Full-screen backgrounds and cameras cover the complete viewport, including the extra vertical area at 16:10. Authored world subjects and critical gameplay staging remain within a centered `1920x1080` safe composition so they keep their proportions and are never vertically stretched. Responsive overlays may use the additional 16:10 space. Positioning must continue to follow `docs/coordinate-spaces.md` rather than mixing world, viewport, and control coordinates.

## Readability and Interaction Rules

The compact profile protects physical usability rather than blindly enlarging the entire interface:

- Primary text should render at approximately `20` physical pixels or larger.
- Secondary metadata may render at approximately `16` physical pixels but must retain sufficient contrast.
- Important icons, controller focus targets, and actionable controls should occupy at least approximately `48x48` physical pixels.
- A constrained layout tightens nonessential margins and empty spacing, reflows content, or becomes scrollable before shrinking essential information below those targets.
- Focus outlines, selected states, and controller prompts remain fully visible.
- No required information or action may depend solely on hover.
- Scroll containers preserve deterministic controller focus and expose every item; they do not silently clip overflowing content.

These are acceptance thresholds, not a mandate to override every font or control. Scenes that already meet them through ordinary anchors and containers remain unchanged.

## Screen Requirements

### Title and global overlays

The title screen, loading and transition overlays, dialogs, tooltips, action hints, and navigation feedback fill or center within the current viewport. Buttons remain readable and controller-reachable without clipped focus decoration at both targets.

### Hub and party management

The hub is an explicit first-class part of handheld acceptance. Coverage includes the hub landing screen, party menu, hero selection and status panels, inventory, equipment details, tuning and modification flows, and every skill-tree view.

At `1280x800`:

- Party and hero panels preserve readable identity, stats, equipment slots, and state indicators.
- Inventory grids and item lists scroll when their content exceeds the available region. Selected-item details and the action needed to equip, tune, or modify remain visible or reachable without collapsing the item grid into illegible rows.
- Equipment comparison data, mod slots, ranks, and costs retain their hierarchy and do not overlap.
- Skill-tree nodes, role anchors, connectors, owned/available/locked states, costs, and focus outlines remain distinguishable.
- Skill trees preserve pan/navigation access to every node. Dense trees use the existing navigation or scrolling space rather than shrinking nodes and text below the compact thresholds.
- Switching between progression and inventory modes must not leave stale sizing, focus ownership, or scroll position that hides the active selection.

The responsive pass will adapt the current information architecture. It will not redesign inventory rules, equipment behavior, progression content, or skill-tree topology.

### Dungeon, map, and terminal

Dungeon backgrounds and cameras cover 16:10 while world interaction coordinates remain correct. HUD elements, hero status, scanner/reticle presentation, terminal entry, dungeon overlays, and the end screen remain within safe bounds.

The redesigned terminal already targets `1200x800` and serves as the reference for responsive sizing, readable protocol rows, scrolling, and controller focus. It will be regression-tested rather than redesigned.

### Combat

Combat retains its current information hierarchy and behavior. At compact size, the turn rail, actor cards, action controls, target presentation, status effects, CT preview, and tooltips may use adjusted dimensions, margins, or spacing.

The turn rail remains readable and scrollable at `1280x800`; its cards, gauges, acting outline, reorder animation, and internal scrollbar remain visually contained. Actions and actor cards must not overlap the rail or leave controller targets below the physical-size threshold. CTB ordering, prediction, recovery, and animation semantics do not change as part of the resolution work.

### Rewards and end states

Reward summaries, dungeon-end statistics, confirmations, and return navigation fit without clipping and remain operable using only the controller.

## Testing Strategy

### Automated coverage

- Unit-test compact/desktop classification, boundary dimensions, runtime profile transitions, and ignored zero-sized resize events.
- Test startup sizing as a pure policy: compact displays select their available native size and larger displays retain the desktop target.
- Instantiate each major root screen at `1280x800` and `1920x1080` and assert that required controls remain within the visible viewport.
- Add focused screen assertions for scroll availability, key control dimensions, focus targets, and rigid minimum-size regressions where stable public seams exist.
- Extend CTB integration coverage to `1280x800` while retaining its `1920x1080` reference assertions.
- Preserve existing terminal coverage at `1200x800` and `1920x1080`.
- Run focused tests while iterating and the complete suite because the viewport policy crosses runtime scenes, navigation, and input presentation.

Purely visual balance, font legibility on the physical device, camera coverage, animation placement, and controller feel remain manual acceptance concerns rather than screenshot-comparison tests.

### Manual acceptance

Complete the controller-driven playable path at native `1280x800`:

1. Launch into the title screen and enter the hub.
2. Exercise party selection, hero details, inventory, equipment, tuning/modification, and each skill tree.
3. Start and navigate a dungeon, use map/scanner interactions, open a terminal, and close nested overlays.
4. Enter representative combat, inspect and scroll the CTB rail, select actions and targets, and observe turn/reorder animations.
5. Complete or exit the run, inspect rewards/end screens, and return to the hub.

At every step verify full-screen coverage, readable text and icons, unclipped content, visible focus, deterministic controller navigation, usable scrolling, correct cursor/reticle coordinates, and no overlap introduced by the compact profile. Repeat a shorter regression path at `1920x1080` to confirm the current desktop composition remains intact.

When hardware is available, perform the `1280x800` pass on a Steam Deck. A desktop window forced to `1280x800` is an acceptable implementation-time proxy but does not replace final physical readability and native-launch verification.

## Documentation Updates

Implementation will update the relevant controller, dungeon, and CTB manual checklists so both `1280x800` and `1920x1080` are explicit acceptance targets. `docs/coordinate-spaces.md` will describe the centered world safe composition and expanded UI viewport if the implementation changes its current guidance.

## Out of Scope

- Separate Steam Deck scenes or duplicated UI trees.
- Steam-specific APIs or device-name detection.
- Exhaustive docked-resolution and ultrawide certification.
- A graphics settings or resolution preferences menu.
- General rendering-performance optimization.
- Gameplay, inventory, equipment, progression, skill-tree, or CTB rule changes.
