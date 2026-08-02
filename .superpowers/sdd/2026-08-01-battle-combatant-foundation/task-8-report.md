# Task 8 — Complete battle combatant foundation

Implementation commit verified before this report-only amendment: `68761ebdab093ff75b6d687e03d0f3f302d8bc80` (`refactor: complete battle combatant foundation`). The final amended commit is recorded in the handoff.

## Implementation

- Removed the remaining gameplay compatibility properties, lifecycle methods, combat mutations, stat delegates, enemy AI delegates, and hero role/Focus delegates from `ActorCard`, `HeroCard`, and `EnemyCard`.
- Kept cards limited to binding, rendering, animation, hover/click input, geometry, popups, and other presentation behavior. Visual code now reads authoritative state directly from the bound combatant.
- Removed card-type knowledge from `BattleManager` encounter spawning. It now instantiates the configured view scene through the typed presentation contract, resolves exactly one root or descendant `CombatantPresentation`, and registers it without treating the view as a gameplay identity.
- Strengthened `DamagePreview` cloning so specialized Hero/Enemy copies preserve all actor stats and damage-relevant runtime state while conditions and traits remain isolated. This includes HP, Guard, CT, CT speed scale, battle priority, Breach/Danger/defeat state, and Hero Focus; targetability plus specialized AI and role-planning state are intentionally outside the damage-preview copy. Explicitly preserved a trait's runtime `current_tier`, which Godot's recursive resource duplicate did not copy.
- Migrated the remaining card-oriented fixtures to act on bound combatants and assert the card/view boundary directly.
- Added direct headless Hero and Enemy tests for setup, equipment traits, boons, injury HP, Focus spend/refund signals, defeat/revival signals, enemy scaling and authored-data isolation, recovery intent, cooldown completion, and target revalidation.
- Added an unchecked manual foundation regression section for controller-only and mouse interaction with the current 2D presentation.

## TDD and regression evidence

1. Replaced the narrow nonvisual preview-copy check with one consolidated specialized-copy contract.
   - RED: the copied trait lost its runtime `current_tier` and returned the default tier.
   - GREEN: `_copy_target` explicitly transfers `current_tier` after deep duplication; all copied condition and trait resources remain distinct from live state.
2. Added direct Hero combatant coverage rather than exercising gameplay through `HeroCard` compatibility methods.
   - Covered setup resource application, exact Focus publications for spend/refund, and exactly-once defeat/revival lifecycle signals.
3. Added direct Enemy combatant coverage rather than exercising AI through `EnemyCard` delegates.
   - Covered scaled setup without authored-data mutation, model-owned recovery intent and clear, cooldown accounting, and deterministic target revalidation.
4. Replaced compatibility expectations in the card-binding suite with an explicit presentation boundary.
   - Cards expose bound identity and view/input operations but no duplicated HP, Guard, CT, role, Focus, AI, intent, lifecycle, or combat-mutation APIs.
5. The final manager card-type cleanup initially made view setup blocking by awaiting entrance visuals.
   - RED: the controller playable loop was 1/2 with 84/85 assertions because combat actions were still unpopulated when inspected.
   - GREEN: preserving the original non-blocking setup timing restored 2/2 tests and 104 assertions while retaining the type boundary.

## Dirty-workspace verification

Every Godot invocation used `HOME=/tmp/mars-godot-home` and Godot 4.6.3.

- Headless editor import and parse: exit 0 with no parser errors.
- `damage_preview`: 39/39 passing, 173 assertions.
- `hero_combatant`: 4/4 passing, 17 assertions.
- `enemy_combatant`: 4/4 passing, 21 assertions.
- `card_combatant_binding`: 11/11 passing, 56 assertions.
- `actor_card_target_presentation`: 8/8 passing, 61 assertions.
- `ctb_action_content`: 4/4 passing, 20 assertions.
- `battle_controller_navigation`: 78/78 passing, 434 assertions.
- `controller_playable_loop`: 2/2 passing, 104 assertions.
- `battle_revival`: 6/6 passing, 27 assertions.
- `enemy_ai_intents`: 23/23 passing, 71 assertions.
- `battle_responsive_layout`: 2/2 passing, 12 assertions.
- Complete GUT suite: 924/925 passing, 14,537/14,538 assertions across 68 scripts.
- The sole full-suite failure was the intentionally preserved unrelated user edit in `src/dev/endgame_battle_lab.tscn`: its enemy HP multiplier is `1.0`, while the committed test fixture expects `5.0`.

Discovery and hazard audits:

- The repository contains exactly 68 configured `test_*.gd` files and GUT discovered exactly 68 scripts.
- No `pending`, `skip_if`, `skip_test`, or `gut.pending` markers were found.
- The full-run log contained no parser errors, script errors, unexpected test errors, skipped tests, or pending tests. Its only failure was the known dirty lab-scene assertion.
- Card-type scans found no `ActorCard`, `HeroCard`, or `EnemyCard` references in gameplay scripts, damage code, or `CTBSimulator`. Remaining references are confined to the visual card classes and `CardCombatantPresentation` adapter.
- Duplicate-state and gameplay-wrapper scans found no card-owned combatant fields or gameplay delegate methods.
- `git diff --check` passed.

The recurring macOS certificate-store warning, expected test error probes, the existing ignored-inner-class warnings, and documented successful-test shutdown diagnostics were unchanged.

## Clean committed-state verification

- Cloned implementation commit `68761ebdab093ff75b6d687e03d0f3f302d8bc80` with `--no-local` into `/tmp/mars-task8-verify.sF9QHE/repo` and used `/tmp/mars-task8-verify.sF9QHE/home` as its isolated `HOME`/save root.
- After the clean clone's one-time asset import, headless editor import and parse exited 0 with no parser, script, or resource-load errors.
- Complete GUT suite: 925/925 passing, 14,538 assertions across exactly 68 scripts, exit 0.
- The clean full-run hazard scan found no failing, skipped, pending, parser-error, script-error, or unexpected-error entries.
- `git status --short` remained empty in the verification clone; only ignored Godot import cache files were generated.
- The temporary `/tmp/mars-task8-verify.sF9QHE` verification root was removed after the results were captured.
- The final amendment changes this Markdown report only; the verified source, scene, data, and test tree is identical.

## Files changed

- `docs/testing/ctb-combat-checklist.md`
- `src/battle/actor_card.gd`
- `src/battle/battle_manager.gd`
- `src/battle/damage/damage_preview.gd`
- `src/battle/enemy_card.gd`
- `src/battle/hero_card.gd`
- `test/integration/test_battle_controller_navigation.gd`
- `test/integration/test_battle_revival.gd`
- `test/integration/test_card_combatant_binding.gd`
- `test/integration/test_controller_playable_loop.gd`
- `test/integration/test_enemy_ai_intents.gd`
- `test/unit/test_actor_card_target_presentation.gd`
- `test/unit/test_ctb_action_content.gd`
- `test/unit/test_damage_preview.gd`
- `test/unit/test_enemy_combatant.gd`
- `test/unit/test_hero_combatant.gd`
- `.superpowers/sdd/2026-08-01-battle-combatant-foundation/task-8-report.md`

The unrelated user edit in `src/dev/endgame_battle_lab.tscn` was preserved and excluded from the commit.

## Manual checks and asset handoff

- No interactive visual, mouse, or physical-controller acceptance was performed. The new checklist items remain unchecked.
- Automated controller-loop, target-navigation, revival, enemy-intent, card-presentation, and responsive-layout coverage are green.
- The combatant/presentation boundary is ready for the planned 3D enemy-view work. The next asset handoff should provide local paths for the imported Quaternius environment and enemy model assets; no external kit files were added in this task.

## Fix Round 1 — Typed presentation spawning

Implementation fix commit verified before this report-only amendment: `0318a776bf860ee38bf3c2f1807b098ab9b85ca2` (`fix: type combatant presentation spawning`). The final amended commit is recorded in the handoff.

### Findings addressed

- Replaced the manager's hidden card-root protocol with `CombatantPresentation.setup_view(BattleCombatant)`. The base implementation binds the combatant, while `CardCombatantPresentation` delegates to the existing typed Hero/Enemy card setup internally and preserves its non-blocking entrance timing.
- Added typed `CombatantPresentation.particles_requested(position, type)` events. The card adapter forwards its visual particle request through this signal, and the presentation registry connects and disconnects it alongside target input exactly once.
- Added one generic manager spawn boundary that instantiates a configured view under a generic `Node` root, recursively resolves exactly one root or descendant `CombatantPresentation`, asserts a clear error for an invalid count, invokes typed setup, and registers it.
- Removed manager assumptions about a root `setup_from_combatant` method, a child named `CombatantPresentation`, and a root `spawn_particles` signal. `BattleManager` contains no concrete card type or cast.
- Broadened hero and enemy presentation roots from `Control` to `Node`, allowing a future `Node3D` view root while preserving the current scene's existing `HBoxContainer` paths.
- Made optional particle playback safe for headless managers that intentionally have no `FXManager`.
- Removed the unused `ActorCard.MAX_GUARD`; authoritative Guard clamping remains in `BattleCombatant.MAX_GUARD`.
- Corrected the preview-copy claim above to all damage-relevant runtime state and explicitly documented the omitted targetability, specialized AI, and role-planning state.

### TDD and regression evidence

1. Added real runtime-packed view scenes with a bare `CombatantPresentation` root and a presentation nested beneath a non-card `Node3D` root.
   - RED: `card_combatant_binding` was 11/13 passing with 56/58 assertions because the typed manager spawn boundary and presentation event contract did not exist.
   - GREEN: both shapes bind their exact models, register under the manager, retain their generic roots, require no card method/signal, and unregister cleanly when freed.
2. Added presentation event lifecycle and card-adapter forwarding coverage.
   - Replacement/teardown coverage verifies duplicate registration routes one event, the replaced view routes none, the replacement routes one, and an unregistered view routes none.
   - Mutation RED: with card particle forwarding removed, `card_combatant_binding` was 13/14 passing with 75/76 assertions because `particles_requested` was not emitted.
   - Final GREEN after typed forwarding and test refactor: 14/14 passing, 74 assertions.
3. Broader AI coverage exposed the newly centralized visual event at a headless boundary.
   - RED: `enemy_ai_intents` was 22/23 passing with 71/72 assertions because a manually registered card presentation requested particles from a manager with no `FXManager`.
   - GREEN: the optional visual consumer now returns when the service is absent; `enemy_ai_intents` is 23/23 passing with 71 assertions and the real damage turn remains intact.
4. The real controller loop proves card setup remains non-blocking through the new typed presentation entry point: 2/2 passing, 104 assertions.

### Dirty-workspace verification

Every Godot invocation used `HOME=/tmp/mars-godot-home` and Godot 4.6.3.

- Headless editor import and parse: exit 0 with no parser errors.
- `card_combatant_binding`: 14/14 passing, 74 assertions.
- `damage_preview`: 39/39 passing, 173 assertions.
- `hero_combatant`: 4/4 passing, 17 assertions.
- `enemy_combatant`: 4/4 passing, 21 assertions.
- `actor_card_target_presentation`: 8/8 passing, 61 assertions.
- `ctb_action_content`: 4/4 passing, 20 assertions.
- `battle_controller_navigation`: 78/78 passing, 434 assertions.
- `controller_playable_loop`: 2/2 passing, 104 assertions.
- `battle_revival`: 6/6 passing, 27 assertions.
- `enemy_ai_intents`: 23/23 passing, 71 assertions.
- `battle_responsive_layout`: 2/2 passing, 12 assertions.
- Complete GUT suite: 927/928 passing, 14,555/14,556 assertions across 68 scripts.
- The sole full-suite failure remains the intentionally preserved unrelated user edit in `src/dev/endgame_battle_lab.tscn`: its enemy HP multiplier is `1.0`, while the committed test fixture expects `5.0`.

Discovery and hazard audits:

- The repository still contains exactly 68 configured `test_*.gd` files and GUT discovered exactly 68 scripts.
- No pending or skip directives were found; the full log contained no parser, script, unexpected, skipped, or pending test errors.
- `BattleManager` contains no card types/casts, dynamic setup calls, hard-coded presentation child lookup, or root particle-signal connection.
- Card types remain confined to the card presentation layer; gameplay-domain card, duplicate-state, and wrapper scans remain clean.
- `ActorCard.MAX_GUARD` has no remaining declaration or use, and `git diff --check` passed.

### Clean committed-state verification

- Cloned fix commit `0318a776bf860ee38bf3c2f1807b098ab9b85ca2` with `--no-local` into `/tmp/mars-task8-fix1-verify.mkhtzZ/repo` and used `/tmp/mars-task8-fix1-verify.mkhtzZ/home` as its isolated `HOME`/save root.
- After the clean clone's one-time asset import, headless editor import and parse exited 0 with no parser, script, or resource-load errors.
- Complete GUT suite: 928/928 passing, 14,556 assertions across exactly 68 scripts, exit 0.
- The clean full-run hazard scan found no failing, skipped, pending, parser-error, script-error, or unexpected-error entries.
- `git status --short` remained empty in the verification clone; only ignored Godot import cache files were generated.
- The temporary `/tmp/mars-task8-fix1-verify.mkhtzZ` verification root was removed after the results were captured.
- The final amendment changes this Markdown report only; the verified source, scene, data, and test tree is identical.

### Files changed

- `src/battle/actor_card.gd`
- `src/battle/battle_manager.gd`
- `src/battle/presentation/card_combatant_presentation.gd`
- `src/battle/presentation/combatant_presentation.gd`
- `test/integration/test_card_combatant_binding.gd`
- `.superpowers/sdd/2026-08-01-battle-combatant-foundation/task-8-report.md`

The unrelated user edit in `src/dev/endgame_battle_lab.tscn` remains preserved and excluded. Interactive visual, mouse, and physical-controller acceptance remains unchecked; no kit assets were added in this fix round.

## Fix Round 2 — Release-safe view validation and encounter rollback

Implementation fix commit: `5a8226674a74965f7f30061cbd8875ed4b3d1294` (`fix: reject invalid combatant presentation scenes`). Verification was recorded separately in docs commit `0e059056807f41ef669ebdc04792258b2dd020fc` so the report could name the exact tested source commit.

### Findings addressed

- Replaced debug-only presentation-scene assertions with ordinary runtime guards for null scenes, invalid parents or combatants, failed instantiation, and zero or multiple `CombatantPresentation` nodes.
- Collected and validated the presentation while its view root was still off-tree. Invalid roots are freed without setup, model binding, registry entries, event handlers, or an adopted child.
- Made encounter callers detect a failed view spawn, abort before fades, passives, or turn selection, and roll back every combatant and view created by that encounter attempt. Rollback removes model signals, manager back-references, roster entries, registry state, and scene-tree roots, including participants created before a later failure.

### TDD and verification evidence

- RED: `card_combatant_binding` passed 14/17 tests and 87/102 assertions. Zero- and two-presentation scenes asserted only after entering the tree, while encounter startup retained the invalid participant and continued into fade/passive/turn work.
- GREEN: `card_combatant_binding` passed 18/18 tests with 111 assertions, including missing-input runtime guards and rollback after a valid hero view precedes an invalid enemy view.
- Dirty-workspace full suite: 931/932 tests and 14,592/14,593 assertions. The sole failure was the preserved lab-scene multiplier mismatch.
- Clean clone of the exact implementation commit: headless parse exited 0 and the complete suite passed 932/932 tests with 14,593 assertions.

## Final binding and cancellation review rounds

### Release-safe setup and presentation ownership

- `e7a9063e56b535468f5e0afd19653bbffe94d7f6` (`Guard combatant presentation binding`) made combatant, card, and presentation binding report success explicitly. Spawn validates that setup succeeded and that the presentation owns the exact requested combatant before registration; failure frees the partially adopted view and leaves no registry or event state.
- Specialized Hero/Enemy card mismatches, no-op setup, invalid values, card rebinding, and offering one presentation to two combatants now fail through ordinary runtime errors rather than release-elided assertions.
- `BattleManager.register_presentation` now returns success or failure and rejects invalid values, combatant mismatches, and a presentation already owned by another combatant without disturbing the first valid registration.
- RED for the initial three binding findings: `card_combatant_binding` passed 18/21 tests and 115/131 assertions. The wrong specialized card asserted, no-op setup remained adopted and registered, and one presentation appeared under two combatants.
- `be9b39cbb65c5549f7a25389fd53685300232305` (`Reject presentation setup rebinding`) added the remaining direct setup-rebind guard so a registered presentation preserves its first combatant identity.

### Cancellation-safe presentation operations

- `2c44190cec724edee2e78627028dc7f652e97b4c` (`Cancel presentation waits on view teardown`) introduced `PresentationOperation`, a small manager-visible completion contract for acting transitions, action hiding, and health synchronization. Presentation exit, replacement, and unregistration complete pending operations so manager awaits resume and their existing generation/identity guards can run.
- Real card slide, action-fade, and health tweens are wrapped by the same contract. The cards remain presentation-only, and model state remains authoritative.
- Regressions free and replace views during acting, hide-action, and health operations and verify bounded manager completion rather than a suspended coroutine.
- `04365d656c5d356e29b4534373c57aa3e8a463e3` (`Stabilize presentation lifecycle transitions`) completed the boundary by covering direct invalid/repeated binding, failed card binding, explicit unregistration, freed-combatant pruning, and replacement of an in-flight card health operation.

## Final exact-source verification

Source commit: `04365d656c5d356e29b4534373c57aa3e8a463e3`.

- Independent final boundary re-review: PASS with no findings.
- Final focused `card_combatant_binding`: 26/26 tests, 169 assertions.
- Final focused `presentation_operation_cancellation`: 11/11 tests, 37 assertions.
- Working checkout full suite: 950/951 tests and 14,704/14,705 assertions. The only failure is the protected dirty `src/dev/endgame_battle_lab.tscn`, whose multiplier is `1.0` while the committed scene and test expect `5.0`.
- Clean exact-commit clone at `/private/tmp/mars-final-7c8fYA`: the second headless import/parse exited 0 with only the documented macOS certificate warning and no parser errors; the complete suite exited 0 with 951/951 tests and 14,705 assertions.
- No interactive visual, mouse, physical-controller, touch, or Steam Deck acceptance was performed. Every manual checklist item remains unchecked.
- This final amendment changes only the Task 8 report, its progress ledger, and the existing CTB checklist. The tested source, scene, data, and test tree remains identical to `04365d656c5d356e29b4534373c57aa3e8a463e3`.
