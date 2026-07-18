# Endgame Enemy AI and Combat Benchmark Design

## Summary

Add a reusable, data-driven cooldown AI for enemies and a save-isolated endgame battle lab that answers whether Redshift's completed three-hero combat system remains strategically interesting at maximum progression. The first content target is a four-enemy human-and-drone tactical cell, followed by a two-enemy command pair.

The existing combat-content framework remains authoritative. Enemy actions continue to use `Action`, `ActionEffect`, `Condition`, `Trigger`, the shared damage resolver, and the shared presentation pipeline. A new enemy-only ability layer supplies cooldowns, conditional priorities, and target-selection rules without adding AI fields to hero-compatible `Action` resources or duplicating combat arithmetic.

Exact new-enemy skill content has a required user-review checkpoint before authoring. The architecture, benchmark compositions, intended interactions, and initial ability concepts are approved; names, coefficients, cooldowns, triggers, and final skill selections may be refined at that checkpoint.

## Goals

- Determine whether combat remains fun and tactically expressive with Asher, Echo, and Sands fully developed.
- Give enemies readable but non-scripted behavior through deterministic cooldown readiness, reactive priorities, and seeded tie-breaking.
- Preserve visible intent as reliable planning information.
- Reuse the current action, effect, condition, trigger, damage, preview, and tooltip systems.
- Support conditional enemy behavior such as low-HP healing, target-Focus damage, target-Guard damage, imminent-turn disruption, and buffs removed through Breach.
- Exercise role shifting, Focus spending, Guard management, Breach, healing, buff/debuff application, cleansing, and condition removal.
- Provide a direct, repeatable benchmark that never reads or writes ordinary campaign save data.
- Protect the new rules with deterministic unit and integration coverage before tuning encounter content.

## Non-goals

- Final release balance or a complete endgame campaign.
- A general-purpose visual enemy-AI editor.
- Procedural enemy-kit generation.
- Mutants, aliens, summons, Dodge, interruptible actions, hard Stun, or Silence in the initial benchmark.
- Final portraits, animation, sound, or other presentation production work.
- Save migration or mid-battle persistence for AI cooldown state.
- Rebalancing hero skills during the AI-foundation phase.
- Treating raw win rate as sufficient evidence that combat is fun.

## Existing Framework Assessment

The current attack framework is the correct foundation:

- `Action` defines cost, recovery, targeting, descriptive content, and ordered effects.
- `ActionEffect` subclasses execute damage, healing, Guard, CT, conditions, and other mutations.
- `Condition` and `Trigger` represent buffs, debuffs, passives, reaction timing, and removal rules.
- `Effect_Damage`, `DamageScalingRule`, `DamageResolver`, `DamagePreview`, and action presentation share authoritative combat arithmetic.
- Enemy intent already consumes the shared damage and presentation paths.

New enemy actions must be modeled after current enemy and hero actions by composing these resources. They must not calculate damage inside AI code, maintain separate intent formulas, or special-case an ability name in `EnemyCard`.

The existing enemy decision layer is not sufficient for the benchmark:

- `EnemyData.action_deck` chooses a random or authored sequence rather than evaluating readiness and battlefield state.
- `AIOverride` provides a small fixed trigger list and returns the first matching action.
- Generic targeting cannot express highest Focus, highest Guard, lowest HP percentage, closest upcoming turn, or intentional marked-target preference.
- Repeated intent refreshes are correctly separated from sequence advancement today; the replacement must preserve that property for cooldowns and tie-breaking.

## Enemy Ability Definitions

An enemy ability is immutable authored data that wraps an ordinary `Action`.

Each definition contains:

- a stable, non-empty ability ID unique within its enemy kit;
- an `Action` resource;
- a non-negative cooldown in enemy turns;
- an initial cooldown from zero through the base cooldown;
- an optional one-time-use flag; and
- one or more ordered decision rules.

A cooldown of zero defines a free action. Free actions participate in ordinary priority evaluation and may become strategically preferred when a condition is met. Every kit must contain at least one unconditional usable free action so the enemy always has a safe decision.

Each decision rule contains:

- an integer priority;
- zero or more typed conditions that must all pass;
- a typed target selector; and
- an optional reason label used by tests and diagnostic logging.

Multiple rules may reference the same ability. Mind Spike, for example, can have a high-priority rule when a hero holds at least five Focus and a low-priority unconditional rule using the same highest-Focus selector. Cooldown and one-time state belong to the ability, not to an individual rule.

Conditions and selectors remain typed data rather than action-name checks. The initial condition vocabulary includes:

- always;
- first enemy turn;
- self HP percentage at or below a threshold;
- any ally HP percentage at or below a threshold;
- any hero Focus at or above a threshold;
- any hero Guard at or above or below a threshold;
- any hero Breached;
- self or ally missing Guard;
- a living actor possessing or lacking a named condition;
- at least a configured number of living heroes or allies; and
- a hero within a configured distance of their next CT turn.

The initial selector vocabulary includes:

- self;
- all living heroes;
- all living allies;
- seeded valid hero;
- preferred-condition hero with a seeded valid fallback;
- highest-Focus hero;
- highest-Guard hero;
- lowest-Guard hero;
- hero closest to acting;
- lowest-HP-percentage ally;
- least-Guard ally; and
- ally furthest from acting.

Offensive selectors always apply ordinary target eligibility last. Untargetable heroes are excluded, and any valid Taunting hero overrides the selector. An ability can otherwise deliberately ignore the Officer's targeted preference when its identity requires highest Focus or highest Guard.

## Decision Engine and Runtime State

Decision evaluation belongs in a testable non-UI engine. It consumes an enemy, its immutable kit, its per-card runtime state, and a read-only battle context. It returns a decision containing the ability, resolved targets, winning rule, and diagnostic reason.

Evaluation proceeds in this order:

1. Mandatory Breach recovery overrides the ordinary kit.
2. Exclude abilities that are cooling down or exhausted by one-time use.
3. Evaluate each remaining rule and resolve valid targets.
4. Exclude rules whose conditions fail or whose targets are empty.
5. Select the highest priority.
6. Break equal-priority ties with longer base cooldown first.
7. Break any remaining action or target tie deterministically from the encounter seed, enemy battle priority, enemy turn number, and stable candidate identities.
8. Fall back to the required unconditional free action if no conditional rule remains usable.

Longer cooldown is a tie-breaker, not an unconditional preference. An emergency heal can therefore outrank a long-cooldown attack through authored priority.

Each `EnemyCard` owns mutable runtime state:

- remaining cooldown by ability ID;
- used one-time ability IDs;
- completed-turn count;
- current intended decision; and
- a stable decision seed derived from encounter state.

Authored `EnemyAbility` and `Action` resources are never mutated. Multiple enemies may safely share them.

## Cooldown Semantics

Initial cooldowns are authored and deterministic for benchmark encounters. A base cooldown of three means an ability is unavailable for the next three completed turns belonging to that enemy.

At encounter setup:

1. Copy each authored initial cooldown into the card's runtime map.
2. Set the completed-turn count to zero.
3. Calculate the opening intent without changing cooldowns.

After the enemy completes a real turn:

1. Decrement positive cooldowns that were already active before the turn.
2. Put the ability just used on its full base cooldown.
3. Record one-time use when applicable.
4. Increment the enemy's completed-turn count.
5. Calculate its next intent.

Mandatory Breach recovery counts as a completed enemy turn and decrements existing cooldowns, but it does not place an ordinary ability on cooldown.

Intent refresh never decrements cooldowns, increments turn count, records use, or consumes mutable random state.

## Intent Lifecycle and Controlled Variation

The opening state is authored and reproducible. Later behavior varies because player action changes conditions, targets, Guard, Focus, CT, buffs, debuffs, Breach state, living actors, and cooldown alignment.

The battle refreshes non-acting enemy intents when relevant actor state changes. A refresh may select a newly urgent rule or a different valid target, but it reads unchanged cooldown state. If an intended target becomes invalid at execution time, the acting enemy performs one final non-mutating re-evaluation. Missing all valid actions is treated as invalid content and reported rather than silently skipping a turn.

Seeded choices must be referentially stable. Repeating the same evaluation with the same battle state returns the same action and target, so UI refreshes do not make intents flicker or make automated tests order-dependent.

## Relationship to Existing Enemy AI

The cooldown decision model becomes the authoritative enemy AI rather than a permanent second path. The six current actor definitions are migrated to ability kits using their existing action resources. Their exact early-game cooldowns and priorities should preserve their broad identities, but sequence parity is not required in this pre-alpha prototype.

After migration:

- `EnemyData.action_deck`, `ai_pattern`, `ai_script_indices`, and `ai_overrides` are removed;
- sequence/random selection and `AIOverride` runtime logic are removed from `EnemyCard`; and
- all enemy intent uses the same ability-definition and decision-engine boundary.

The current actor migration occurs only after the new engine has focused deterministic coverage. It must not rewrite or rebalance the underlying current action resources unless a separately observed defect requires it.

## Required Combat Extensions

### Target-side resource scaling

Existing reusable damage scaling reads the attacker's Focus or Guard. The scaling boundary gains an explicit resource owner, defaulting to attacker for compatibility with current hero content and allowing target for new enemy content.

The generalized rule can read Focus or Guard from the selected owner and contributes through the shared damage request. Mind Spike and the Guard-punishing piercing attack therefore receive identical runtime, preview, tooltip, and intent math.

Presentation labels distinguish attacker and target resources, such as `target Focus` and `target Guard`, rather than reusing the existing `remaining Focus after paying the cost` wording.

### Enemy healing

`Effect_Healing` is generalized from `HeroCard` targets to living `ActorCard` targets. Hero-specific Focus scaling remains conditional on a hero target. Enemy repair actions set `is_revive` to false and cannot select defeated actors.

Healing selection uses lowest HP percentage rather than raw HP so differently sized enemies are compared fairly. Runtime healing, health animation, signals, and intent presentation remain shared.

### Shift timing

The existing `ON_SHIFT` event continues to represent immediate role change and existing `until Shift` removal behavior. A distinct after-Shift-action event fires only after the new role's Shift action resolves, including a required targeted Shift action.

Energy Bomb and later shift-reactive enemy traits use the after-Shift-action event. They do not fire merely because the role index changed, and they do not preempt the hero's new Shift action.

### Condition lifecycle

Condition removal must execute the removed condition's own removal behavior exactly once without recursively firing unrelated conditions. The following removal paths use the same boundary:

- explicit cleansing;
- gaining Guard when authored;
- becoming Breached when authored;
- completing a Shift or after-Shift reaction when authored;
- consuming a next-action buff; and
- ordinary named-condition removal.

Debuff immunity continues through the existing before-debuff hook. A rejected debuff does not enter active conditions, update the queue, or fire ordinary applied effects.

## Endgame Battle Lab

A developer-only battle-lab scene launches either benchmark encounter directly. It uses the production battle scene and content paths but does not create, load, mutate, or save a campaign slot.

The lab builds a benchmark roster from deep duplicates of the three authored heroes:

- every authored role ID is unlocked;
- every valid non-structural progression node is owned at its current content revision;
- derived stats and all nine combat kits are rebuilt through `ProgressionRebuilder`;
- injuries and temporary run boons are cleared; and
- current equipped weapon and armor resources are deep-duplicated.

The primary endgame preset sets duplicated equipment to tier 5 and rank 30 while retaining the currently equipped item identities. It does not invent mod loadouts or proficiency allocations. A skills-only preset retains authored equipment ranks, allowing the influence of role completion and gear completion to be distinguished.

The battle scene accepts an explicit roster override and enemy-level override. Ordinary gameplay continues using `RunManager.party_roster` and the current dungeon tier when overrides are absent. The lab forces enemy Rank 10, uses an explicit encounter, and accepts a fixed seed.

Running the lab must not change singleton save data even after victory or defeat. Benchmark result presentation may report locally but does not award XP, Bits, loot, injuries, or persistent progression.

## Benchmark Encounters

### Four-enemy tactical cell

The initial composition is:

- Officer: multi-hit gun-class coordinator, targeting setup, ally damage buff, and team suppression.
- Psyker: target-Focus damage, CT disruption, party pressure, and an after-Shift Focus hazard.
- Gang Enforcer: self-Guard basic, target-Guard piercing punishment, Breach-removable offensive buff, and a removable speed debuff.
- Defense Drone: free Guard support, urgent low-HP healing, larger Guard support, and limited debuff protection.

The deterministic opening emphasizes setup rather than four simultaneous burst attacks. The fight must allow several plausible first targets. Defeating or Breaching any member changes the enemy team's behavior rather than merely lowering incoming damage.

### Two-enemy command pair

The initial composition is:

- the same Officer, preserving learned behavior; and
- a Siege Drone with a multi-hit free action, visible party pressure, a marked-target heavy attack, and self-protection.

The pair tests concentrated disruption and a readable setup/payoff loop. Killing either member must materially change the remaining fight.

### Skill-content review gate

Before authoring any new action, condition, actor, or encounter resource for these two benchmark compositions, stop and review the concrete kits with the user. The starting concepts from brainstorming are input to that review, not frozen content. The review explicitly confirms:

- action names and descriptions;
- damage coefficients and selected power;
- damage types and hit counts;
- cooldowns and initial cooldowns;
- conditional priorities and thresholds;
- target selectors;
- buff/debuff values and removal triggers; and
- which ideas from the user's enemy-mechanics document enter this first benchmark.

Architecture and current-enemy migration may proceed before this gate. New benchmark enemy content may not.

## Content Validation and Failure Behavior

Startup content validation reports the actor resource, ability ID, field, and reason for:

- empty or duplicate ability IDs;
- null actions;
- negative cooldowns;
- initial cooldowns outside zero through base cooldown;
- missing decision rules;
- unsupported conditions or selectors;
- selectors incompatible with the action's target side;
- a kit without an unconditional usable free action;
- one-time free actions being the only fallback;
- invalid condition thresholds; and
- referenced resources of the wrong type.

Invalid kits are not partially exposed. Runtime failures include enemy and ability context. An invalid planned target triggers one final re-evaluation; failure to produce a legal fallback logs an error and ends that enemy turn safely without mutating another ability's cooldown.

## Automated Verification

Focused unit coverage protects:

- initial and base cooldown timing, including Breach recovery turns;
- free-action conditional priority;
- emergency healing over longer-cooldown attacks;
- longest-cooldown and seeded final tie-breaking;
- repeat evaluation without state or random mutation;
- one-time abilities;
- every initial condition and selector type;
- Taunt and untargetable filtering;
- target death and invalidation re-selection;
- content validation failures;
- attacker- and target-side Focus/Guard scaling;
- execution, preview, tooltip, and intent agreement for contextual scaling;
- enemy healing and non-revival;
- immediate Shift versus after-Shift-action timing; and
- exact-once condition removal and debuff rejection.

Focused integration coverage protects:

- current actors after migration to cooldown kits;
- battle intent updates without cooldown advancement;
- a fully unlocked three-hero lab roster with all nine roles rebuilt;
- primary max-equipment and skills-only presets;
- exact four-enemy and two-enemy compositions;
- save singleton state remaining unchanged after lab victory and defeat; and
- deterministic replay of a fixed encounter seed.

Because this changes enemy turns, targeting, damage scaling, conditions, role shifting, progression-derived benchmark heroes, and battle lifecycle, final automated verification runs the complete isolated-`HOME` GUT suite after focused iteration.

## Manual Playtest Protocol

Tune the four-enemy tactical cell before the command pair. Use fixed seeds for comparison and additional seeds for variation. Record:

- victory or defeat;
- battle duration and total turns;
- hero defeats and revivals;
- enemy kill and Breach order;
- role shifts per hero and roles never entered;
- Focus and Guard states preceding major enemy actions;
- buffs cleansed, debuffs rejected, and buffs removed through Breach;
- enemy healing casts and effective healing;
- abilities repeatedly ignored by the player;
- dominant loops or strategies that trivialize the fight;
- unavoidable or poorly communicated damage; and
- whether each enemy intent change was understandable.

The desired outcome is not a fixed first-attempt win rate. A blind attempt may fail, but the cause should be legible. After learning the enemy team, a skilled player should win consistently through multiple viable strategies rather than one mandatory script.

Manual acceptance also confirms intent readability, CT queue behavior, action timing, controller interaction, and presentation at `1920x1080` and `1280x800`.

## Implementation Sequence

1. Add failing tests for ability validation, cooldown state, decisions, and stable tie-breaking.
2. Implement immutable enemy ability/rule data and the pure decision engine.
3. Integrate per-card state and intent lifecycle without changing combat effects.
4. Generalize target-side resource scaling and enemy healing with presentation parity.
5. Separate immediate Shift and after-Shift-action condition timing and correct condition removal ownership.
6. Migrate current actors to cooldown kits and remove the legacy AI fields and logic.
7. Add the save-isolated max-party battle lab and its automated coverage.
8. Stop for the required user review of concrete benchmark enemy skills.
9. Author and test the Officer, Psyker, Gang Enforcer, and Defense Drone.
10. Playtest and tune the four-enemy tactical cell.
11. Author, test, and tune the Siege Drone and two-enemy command pair.
12. Run focused checks, the full isolated suite, and manual benchmark acceptance.

## Deferred Work

- Mutant or alien factions.
- Dodge and Evasive stack presentation.
- Summons and parent-linked deaths.
- Interruptible enemy actions and Kamikaze.
- Hard Stun and Silence.
- Formation distance or battlefield tile adjacency.
- General player dispelling of enemy buffs.
- A production mission-select entry for the benchmark encounters.
- Final art, audio, animation, rewards, economy, and endgame campaign placement.
