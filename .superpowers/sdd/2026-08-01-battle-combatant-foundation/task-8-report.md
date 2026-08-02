# Task 8 — Complete battle combatant foundation

Implementation commit verified before this report-only amendment: `68761ebdab093ff75b6d687e03d0f3f302d8bc80` (`refactor: complete battle combatant foundation`). The final amended commit is recorded in the handoff.

## Implementation

- Removed the remaining gameplay compatibility properties, lifecycle methods, combat mutations, stat delegates, enemy AI delegates, and hero role/Focus delegates from `ActorCard`, `HeroCard`, and `EnemyCard`.
- Kept cards limited to binding, rendering, animation, hover/click input, geometry, popups, and other presentation behavior. Visual code now reads authoritative state directly from the bound combatant.
- Removed card-type knowledge from `BattleManager` encounter spawning. It now instantiates the configured view scene, binds it dynamically, and registers its `CombatantPresentation` child without treating the view as a gameplay identity.
- Strengthened `DamagePreview` cloning so specialized Hero/Enemy copies preserve all actor stats and runtime combat state while conditions and traits remain isolated. Explicitly preserved a trait's runtime `current_tier`, which Godot's recursive resource duplicate did not copy.
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
