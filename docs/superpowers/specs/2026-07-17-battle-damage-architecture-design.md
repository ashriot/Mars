# Battle Damage Architecture Design

**Date:** 2026-07-17
**Status:** Approved

## Purpose

Establish one authoritative, production-quality damage model for runtime execution, action presentation, enemy intent, content authoring, and automated verification. The design preserves custom damage-effect subclasses while preventing individual effects, previews, and UI surfaces from reimplementing universal combat arithmetic.

This design covers damage math, contextual scaling, hit planning, damage application, extension seams, presentation, and testing. It does not introduce a general combat transaction, replay, rollback, or networking engine. Those systems should be added only if concrete product requirements demand them.

## Approved Gameplay Rules

### Action Cost and Resource Scaling

An action pays its Focus cost before resolving its effects. Focus-scaling damage uses the attacker's remaining Focus after that payment.

Focused Bolt uses the approved curve:

```text
potency = 20% + 20% per remaining Focus
```

It therefore deals 20% power at zero Focus, 40% at one Focus, 120% at five Focus, and 220% at ten Focus.

Mind Storm retains 400% base potency plus 20% of that base potency per remaining Focus. Casting it with exactly five Focus pays the full cost and receives no retained-Focus bonus. Casting it with ten Focus leaves five and doubles its 400% base potency to 800%.

Resource-based values used by one damage effect are resolved after action cost payment. Effect-wide values and the fixed damage-distribution plan are stable for that effect execution unless a specialized subclass explicitly defines per-hit reevaluation.

### Guard and Breach

Guard interaction is an intrinsic consequence of the hit's resolved damage type. Kinetic and Energy hits always shred Guard and advance the existing Vulnerable-to-Breached sequence. Piercing hits never shred Guard or cause Breach. This applies regardless of whether Piercing was authored on the effect or produced by a pre-hit conversion.

Damage-type conversion resolves before Guard interaction. Converting a Kinetic or Energy hit to Piercing therefore suppresses that hit's Guard damage. The separate authored `shreds_guard` Boolean is removed because it permits contradictory combinations and obscures the core damage-type contract.

The hit sequence processes Guard before damage. Reducing the target's final Guard point makes the target Vulnerable according to the existing two-step Guard/Breach model. A later shredding hit against a Vulnerable target causes Breach, and that same breach-causing hit receives the OVR bonus.

### Power, OVR, and PRE

Every damage effect selects ATK or PSY as its base power. OVR is the universal Breach-exploitation stat: every damage instance against a Breached target adds the attacker's OVR, regardless of selected base power, damage type, or whether the source is a chosen action, bonus hit, counterattack, or delayed condition.

PRE is the equivalent universal critical-exploitation stat. A critical hit adds the attacker's PRE as flat power.

```text
effective power =
    selected ATK or PSY
    + OVR when the target is Breached
    + PRE when the hit is critical
```

The runtime must use this additive form. Expressions such as `1 + OVR / ATK` or `1 + PRE / ATK` are derived relative multipliers suitable only for optional presentation; they are not canonical calculations and do not generalize to PSY-powered damage.

### Critical Chance

AIM is the critical-hit percentage. The final chance, including contextual bonuses, is clamped to 0 through 100 at the roll boundary. A single hit makes a single roll. Preview calculations may produce both normal and critical results without consuming random state.

### Defense and Damage Type

KIN and NRG Defense are literal percentage reductions. Each is clamped to 0 through 90 at the calculation boundary for every actor, even if an upstream stat-generation path produces invalid data. Piercing ignores Defense in exchange for never shredding Guard or causing Breach.

```text
kinetic multiplier = 1 - clamp(KIN Defense, 0, 90) / 100
energy multiplier  = 1 - clamp(NRG Defense, 0, 90) / 100
piercing multiplier = 1
```

Defense rating conversion and diminishing returns are intentionally excluded. Authored and displayed Defense remains directly readable as a percentage.

### Damage-Dealt and Damage-Taken Modifiers

Percentage modifiers add within their category. The attacker and target categories then multiply together.

```text
outgoing multiplier = max(0, 1 + sum(damage-dealt modifiers))
incoming multiplier = max(0, 1 + sum(damage-taken modifiers))
```

Two +25% damage-dealt effects therefore produce a 1.50 outgoing multiplier. A 1.50 outgoing multiplier against a target with +20% damage taken produces a combined 1.80 multiplier.

### Canonical Formula and Rounding

After contextual values have been resolved, one damage instance uses:

```text
raw damage =
    effective power
    * resolved potency
    / fixed distribution count
    * defense multiplier
    * outgoing multiplier
    * incoming multiplier
```

The calculation retains floating-point precision through every stage and floors exactly once at the end. When raw damage is positive, the final result is at least one. A zero-power or zero-potency effect may intentionally deal zero; ordinary positive damage cannot disappear solely through rounding.

### Fixed-Budget Split Damage

`split_damage` means the authored potency is a fixed total budget. The distribution count is locked when the effect creates its hit plan:

- an all-enemy attack divides by the number of planned enemy recipients;
- a three-hit random attack divides by three;
- selecting the same random target more than once still consumes one share per planned hit;
- a target dying during execution never changes the divisor or strengthens later shares.

Target validity may redirect or cancel a planned hit according to the effect's targeting rules, but it does not redistribute that hit's share unless a specialized subclass explicitly owns different behavior.

## Architecture

### Damage Execution Template

`Effect_Damage` remains the asynchronous template-method executor. It owns battle-facing orchestration:

- building the effect context and hit plan;
- resolving targets;
- executing pre-hit behavior;
- mutating Guard and causing Breach;
- rolling critical hits;
- requesting contextual damage resolution;
- applying calculated damage;
- playing audiovisual feedback;
- dispatching condition and combat events;
- applying lifedrain and on-hit effects.

It does not own the universal arithmetic and must not reproduce it in private branches.

### Read-Only Combat Context

Context-sensitive mechanics receive a read-only `CombatSnapshot` or narrower `DamageContext`, not unrestricted mutation access to `BattleManager`. The context exposes facts needed for authored rules, such as:

- attacker and target combat state;
- living allies and enemies;
- current Focus, Guard, HP, and conditions;
- Breach and damage-type state;
- action and effect identity;
- stable effect-start facts and current per-hit facts.

Effect-wide scaling normally reads an effect-start snapshot so later hits do not change merely because an earlier hit removed a combatant. Target-specific hit rules may read the current hit context where mechanics explicitly depend on the target's current state.

The context boundary supports future rules such as “+10% potency per other living ally” without adding one-off fields such as `swarm_count` to the universal calculator.

### Contextual Scaling Rules

Reusable battlefield-dependent arithmetic is authored as composable `DamageScalingRule` resources. A rule reads the context and contributes a labeled value through a small set of typed stages, including:

- resolved potency;
- power bonus;
- outgoing damage modifier;
- incoming damage modifier.

Rules cannot replace final damage, bypass Defense, choose their own rounding, or mutate battle state. Each contribution retains a source label so runtime diagnostics and previews can explain the result.

Examples include remaining-Focus potency, current-Guard potency, target-Debuff scaling, missing-HP scaling, and future living-ally or swarm scaling.

### Resolution and Calculation

Contextual resolution produces a typed `DamageRequest` containing only resolved calculation inputs. It has no scene, actor-node, random-number, audio, animation, or await dependency.

`DamageCalculator` is a deterministic, side-effect-free service that accepts a `DamageRequest` and returns an immutable `DamageResult`. The result records at least:

- selected base power;
- OVR contribution;
- PRE contribution;
- effective power;
- base and resolved potency with labeled contributions;
- fixed distribution count;
- raw and clamped Defense;
- defense multiplier;
- outgoing and incoming modifier contributions and multipliers;
- raw floating-point damage;
- final integer damage.

The calculator never queries the battlefield. It performs only the universal arithmetic established in this document.

### Inheritance and Composition

Inheritance remains a supported first-class extension mechanism. `Effect_Damage` exposes narrow override hooks for custom hit planning, target behavior, contextual resolution, and request adjustment. Specialized effects call the base behavior and eventually submit a typed request to the same calculator.

Use inheritance when an effect changes control flow, hit planning, targeting, context timing, or requires a genuinely unique algorithm. `Effect_Damage_Inversion`, whose hit count comes from Guard gained in trigger context, is an appropriate subclass.

Use composition when an effect only scales a number from a readable battlefield fact. A swarm bonus shared by multiple actions belongs in a `DamageScalingRule`, not parallel subclasses.

Subclasses must not copy the complete `execute()` loop or replace the universal OVR, PRE, Defense, modifier, split, rounding, or minimum-damage formula. If a future mechanic genuinely needs to bypass one of those rules, it requires an explicit typed policy or a separately reviewed effect category rather than an incidental override.

## Damage Application and Events

The calculated final damage is the attempted damage. Actual damage dealt is the HP removed after clamping against the target's current HP. Lifedrain uses actual damage dealt and therefore excludes overkill.

Damage application and trigger payloads use the resolved damage type, including pre-hit conversion. A converted Kinetic hit that becomes Piercing must not dispatch a Kinetic-damage event.

Damage-related event context includes the `DamageResult`, attempted damage, actual damage dealt, attacker, target, source effect, source action when present, resolved damage type, critical state, and Breach state used by the calculation. Existing trigger ordering must be made explicit and protected by orchestration tests, including lethal-hit behavior, before implementation changes that reorder reactions.

Guard mutation, damage calculation, HP mutation, lifedrain, and reaction dispatch remain separate steps. The calculator performs none of them.

## Presentation and Authoring

Runtime execution, selected-target previews, enemy intent, and numeric action-description fragments consume the same contextual resolver and calculator. They may request different presentation modes, but they cannot maintain independent formulas.

When an exact target is available, a preview can show the target-specific noncritical and critical result breakdown without rolling RNG. When required battlefield context is unavailable, presentation shows the authored relationship, such as “20% power plus 20% per remaining Focus,” instead of fabricating an exact number.

### Generic Effect Presentation Boundary

`ActionEffect` exposes a generic presentation method that accepts an `EffectPresentationContext` and returns an immutable `EffectPresentation`. The presentation contains an effect-owned clause template, typed or named bindings sourced from effect data/resolver output, and optional labeled breakdown details. It has no dependency on tooltip nodes or action-button layout.

Damage is the first complete effect adopter. `Effect_Damage` owns the authoritative clause for its selected power, resolved potency, hit count, split behavior, damage type, and contextual scaling. It obtains exact numbers and breakdowns from the shared damage resolver/calculator rather than duplicating arithmetic. Direct child damage effects can therefore bind into an action immediately. Damage nested behind an apply-condition or trigger effect remains reachable only through that parent effect's legacy prose until condition/trigger presentation adopts the same interface; focused content validation keeps that transitional prose aligned with its nested resource.

`Action` owns composition. A simple action with no authored description template may join the available child-effect clauses in effect order. A nuanced action retains authored prose and composes child clauses through generic one-based `{effect:N}` bindings. The action owns sequencing words, paragraphs, emphasis, and relationships between effects; it does not own the effect's numbers or mechanical labels.

Narrative action descriptions therefore remain possible without becoming a second mechanical authority. Handwritten expressions such as `{atk*1.25}`, damage-specific placeholders such as `{dmg1}`, and a temporary damage-only binding language must not be authoritative for executed damage.

This damage effort establishes the generic presentation types, the `ActionEffect` interface, action-level automatic/template composition, and complete damage-effect presentation. Migrating every healing, Guard, Focus, CT, condition, and trigger description; redesigning tooltip visuals; and building localization infrastructure are explicitly deferred to a focused follow-up. Existing non-damage prose remains supported during that migration.

Content validation reports invalid damage configuration, unresolved numeric bindings, unsupported scaling rules, and presentation/runtime mismatches with the resource path and effect index.

## Audit Findings to Resolve

Implementation planning must account for every confirmed defect found during the audit:

- Focused Bolt executes the approved 20% plus 20% per remaining Focus curve, but its description advertises a different formula.
- Charged Shot remains at 150% ATK potency; its description must stop advertising 125%.
- Booster Shots remains three 50% ATK hits; its description must stop saying twice.
- Shatter says its damage is split across enemies but does not enable split damage.
- Telekinesis describes Energy damage but defaults to Kinetic damage.
- Reverberate describes PSY-powered damage but its action damage defaults to ATK.
- Shrapnel's primary hit becomes 200% ATK Kinetic damage followed by its existing Piercing Bleed.
- Several Sands actions expose unresolved `{dmg1}` placeholders.
- The separate `shreds_guard` Boolean allows damage resources to contradict the intrinsic type rule and must be removed; Kinetic/Energy resources such as Psionic Pulse and Static Charge currently opt out, while some Piercing resources can inherit the shredding default.
- Damage-received events currently inspect the effect's authored type instead of the resolved type.
- Rapid Fire divides by the current number of living targets while its intent preview hardcodes a divisor of three.
- Enemy intent, action descriptions, and runtime execution independently calculate incomplete versions of damage.
- Weapon AIM currently derives from the KIN Defense rating instead of the AIM rating.
- Enemy Defense generation can bypass the intended cap and reach or exceed complete immunity.
- Lifedrain currently uses pre-rounded attempted damage instead of actual HP removed.
- Pre-hit `damage_bonus`, the no-op `def_mod` branch, and the incomplete action-upgrade `damage_modifier` path are unused or inconsistent extension surfaces.
- The empty-context `IF_ATTACKER_HAS_BUFF` path checks attacker Debuffs instead of Buffs.
- No automated test directly protects the canonical damage formula or battle damage order of operations.

The implementation should verify each content mismatch against intended action design rather than blindly making prose follow runtime data.

## Verification Strategy

### Calculator Unit Tests

Table-driven tests cover:

- ATK and PSY base power;
- universal OVR on Breached targets for every damage type and source classification;
- PRE on critical hits and combined OVR plus PRE;
- KIN/NRG Defense at below-zero, ordinary, 90, and above-90 inputs;
- Piercing Defense bypass;
- additive within-category and multiplicative cross-category modifiers;
- nonnegative modifier clamps;
- fixed split divisors;
- one final floor and positive minimum damage;
- intentional zero-power and zero-potency results.

Calculator tests use plain requests and require no scene tree, battle manager, audio singleton, random roll, or frame wait.

### Scaling-Rule Tests

Each reusable rule is tested against small immutable context fixtures. Coverage includes zero, ordinary, and cap/boundary values; source labels; effect-start snapshot behavior; target-specific per-hit behavior; and combinations of multiple rules.

Focused Bolt, Mind Storm, Shatter, target-Debuff scaling, and at least one living-ally/swarm fixture protect the extension model.

### Extension Contract Tests

A minimal test subclass verifies every supported `Effect_Damage` hook without replacing the execution loop. `Effect_Damage_Inversion` verifies context-derived hit planning. Tests establish that subclasses still use the canonical calculator and cannot silently skip universal rules.

### Battle Orchestration Tests

Focused integration tests protect:

- Focus payment before remaining-Focus scaling;
- AIM clamping and deterministic critical-roll boundaries;
- the Vulnerable-to-Breached hit receiving OVR;
- intrinsic Kinetic and Energy hits always shredding Guard;
- intrinsic and converted Piercing hits never shredding Guard or causing Breach;
- resolved damage-type event dispatch;
- stable split budgets across target death and repeated random selection;
- actual-damage lifedrain excluding overkill;
- on-hit and lethal-hit trigger ordering;
- final result application to HP.

RNG is injected or replaced by a deterministic roll seam so crit and random-target behavior can be asserted without brittle seeds or timing.

### Production Content Validation

An integration test enumerates every production `Action`, `Condition`, and nested `Effect_Damage`. It validates typed configuration, structured numeric bindings, damage-type presentation, hit-count presentation, split semantics, power-type presentation, supported scaling rules, and loadability.

Presentation tests confirm that action details and enemy intent consume calculator/resolver output rather than independent formulas. Manual battle acceptance remains responsible for animation timing, popup readability, audio feel, and overall combat feedback.

## Implementation Boundaries

The refactor should proceed by establishing characterization tests and the pure calculator first, then moving runtime execution, previews, and content onto the shared boundary. Content corrections should be reviewable and separated from structural changes where practical.

The work does not require a general-purpose event-sourcing engine. The typed request/result, read-only context, scaling-rule composition, and narrow subclass hooks are the intended production architecture until concrete mechanics demonstrate a need for a broader combat transaction system.
