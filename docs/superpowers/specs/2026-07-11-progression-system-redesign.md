# Progression System Redesign

## Purpose

Replace the editor-authored nested `RoleNode` resource trees and UI-owned purchase sequence with validated JSON content, stable node identity, typed effects, and an atomic hero-progression transaction boundary.

The system must support rapid alpha/beta balancing and later release-era tree revisions without making routine content edits destructive to player progression.

## Scope and Constraints

- XP and node ownership are always hero-specific.
- Role unlocking remains a separate progression mechanism.
- Each node has at most one prerequisite parent.
- Each node grants exactly one effect.
- Role content loads at startup only; hot reload is excluded.
- No custom visual editor is included.
- Existing prototype saves are intentionally unsupported by the initial migration.
- The first implementation converts all existing role trees and removes the legacy nested node-resource system.

## Authoritative Content Format

Each role owns one JSON file containing metadata, revision information, and a flat node list. JSON is authoritative for progression topology, costs, effects, and layout. Existing Godot resources remain authoritative for actions, passives, icons, and other combat content referenced by a node.

Example:

```json
{
  "schema_version": 1,
  "role_id": "gun",
  "content_revision": 1,
  "nodes": [
    {
      "id": "gun.basic_training",
      "parent": null,
      "rank": 1,
      "column": 0,
      "xp_cost": 100,
      "effect": {
        "type": "stat",
        "stat": "ATK",
        "amount": 1
      }
    },
    {
      "id": "gun.burst_fire",
      "parent": "gun.basic_training",
      "rank": 2,
      "column": 0,
      "xp_cost": 200,
      "effect": {
        "type": "action",
        "resource": "res://data/heroes/asher/actions/burst_fire.tres",
        "slot": 1
      }
    }
  ]
}
```

Node IDs are explicitly authored and immutable once distributed to testers or players. Reordering JSON, changing visual layout, or changing ancestry must not alter identity.

## Validation and Loading

A startup loader parses each role file into immutable runtime definitions and builds indexes by role ID and node ID. Invalid content fails startup clearly; the loader must not expose a partially loaded role.

Validation includes:

- Supported `schema_version`.
- Unique role and node IDs.
- Node IDs belong to their declared role namespace.
- Exactly one root.
- Every non-root parent exists in the same role.
- No cycles or unreachable nodes.
- One parent maximum.
- Positive XP costs.
- Valid integer rank and column layout values.
- Valid effect type and required fields.
- Recognized stat names.
- Referenced action/passive/resource paths exist and have the expected resource class.
- Action slot bounds are valid.

Errors identify the source file, node ID when available, field, and reason. An automated content test loads and validates every role JSON file.

## Runtime Model

Runtime progression content is separated from mutable hero progression state.

`RoleTreeDefinition` contains role ID, content revision, root ID, ordered node definitions, and node/child indexes.

`ProgressionNodeDefinition` contains stable ID, parent ID, rank, column, XP cost, and one typed effect.

`ProgressionEffect` is a typed definition supporting the current reward categories:

- Stat modification.
- Action unlock with explicit resource and slot.
- Passive unlock with explicit resource.
- Shift-action unlock with explicit resource.

The effect model is one effect per node. It can be changed to an array in a future schema version if a real multi-effect use case appears.

`HeroData` owns mutable hero state but does not validate or execute purchases. It stores available XP and per-role progression records.

## Atomic Purchase Boundary

A non-UI `ProgressionService` owns node-purchase rules and state mutation.

Conceptual interface:

```gdscript
var result := progression_service.purchase_node(hero, role_id, node_id)
```

The service validates, in order:

1. Hero, role, and node exist.
2. The hero has unlocked the role.
3. The node is not already owned.
4. The prerequisite is owned, unless the node is the root under the configured default-root policy.
5. The hero can afford the node.
6. The effect and resulting derived state are valid.

Only after validation does it atomically deduct XP, record the node and price paid, and rebuild derived progression state. Failure changes nothing.

The result is typed, with at least:

- `PURCHASED`
- `INVALID_HERO`
- `ROLE_LOCKED`
- `NODE_NOT_FOUND`
- `ALREADY_OWNED`
- `PREREQUISITE_LOCKED`
- `INSUFFICIENT_XP`
- `INVALID_EFFECT`

A successful result includes hero, role ID, node ID, XP paid, and resulting XP. UI/audio/persistence behavior is excluded from the service.

## Derived Stats and Combat Kits

One effect-application pipeline rebuilds all derived progression output from owned nodes. It replaces separate traversal logic for stats and battle roles.

Rebuilding:

- Begins from equipment/base hero state.
- Iterates owned nodes in deterministic role/tree order.
- Applies each typed effect through one dispatcher.
- Produces actor stats and role combat kits.
- Does not mutate authored definitions.
- Reports invalid saved ownership or effects rather than silently applying partial state.

Role unlocking remains external; only unlocked roles contribute active battle-role definitions according to existing game rules.

## Hub Integration

The hub renders immutable definitions and progression state. It does not spend XP or append node IDs directly.

On input:

1. UI submits hero, role ID, and node ID to `ProgressionService`.
2. On `PURCHASED`, the hub plays success feedback, saves, refreshes the matching hero stats, and refreshes affordability across visible trees for that hero.
3. On a rejected result, the hub plays appropriate feedback and does not save.

The existing sibling-affordability and exactly-once persistence behavior remains protected by integration tests.

## Save State and Future Release Compatibility

The redesigned prototype intentionally starts with a new save representation. After that boundary, ordinary content tuning remains compatible.

Per-role hero progression stores:

- Last accepted role `content_revision`.
- Owned node IDs.
- XP actually paid for each owned node.

Recording historical purchase prices and the accepted content revision preserves the information a future refund/reconciliation system will need. This redesign stores that information but does not implement automatic resets or refunds.

Compatible minor edits include:

- XP-cost changes.
- Stat/effect-value balancing.
- Text and presentation changes.
- Rank/column layout changes.
- Prerequisite restructuring while retained owned IDs remain semantically supported.

Minor edits do not retroactively adjust XP already paid.

The data model reserves `content_revision` for structural changes. A future reconciliation feature should use an explicit policy rather than inferring compatibility:

- Default structural policy should reset only the changed role.
- The hero should receive the sum of historical XP paid for nodes reset from that role.
- Removed node IDs should be detected and refunded from their stored purchase prices.
- Default/root unlock policy should be reapplied.
- The accepted revision should update only after reset and rebuild succeed.
- A deliberate hero-wide reset operation may reset and refund every role for exceptional redesigns.

That future refund operation must be deterministic, idempotent, and logged. Until it is implemented, a content revision mismatch must be reported clearly and must not silently mutate progression.

## Authoring and Testing Workflow

During alpha, beta, and release balancing:

1. Edit a role JSON file.
2. Run the content validator.
3. Review a generated summary of node count, total XP, effect distribution, ranks, and branches.
4. Test in game from startup.
5. Commit the readable JSON diff.

Required automated coverage includes:

- Valid and invalid schema fixtures.
- Duplicate IDs, missing parents, multiple roots, cycles, and invalid resources.
- Stable IDs across reorder/layout/cost changes.
- Every purchase rejection with zero mutation.
- Successful atomic purchase and historical price recording.
- Deterministic effect rebuild for stats and combat kits.
- Save round trips.
- Cost changes without retroactive XP mutation.
- Historical purchase prices and accepted content revision survive save round trips.
- Revision mismatch is detected and reported without silently mutating progression.
- Hub success/failure event chain and sibling refresh.
- Validation of every converted production role file.

## Migration Sequence

Implementation proceeds in independently testable phases:

1. Define JSON schema, immutable definitions, loader, validator, fixtures, and content summary.
2. Add typed effects and deterministic effect application.
3. Add per-role hero progression state and atomic purchase service.
4. Detect and report revision mismatches without implementing reset/refund behavior.
5. Migrate hub rendering and purchase feedback to the new service.
6. Convert every existing role tree to JSON and verify behavioral parity.
7. Switch runtime loading to JSON and intentionally reset incompatible prototype progression saves.
8. Remove legacy `RoleNode` nested resources and obsolete traversal/purchase code.
9. Run full automated and manual verification before adding further skill-tree content.

## Deferred Work

- Custom visual tree editor.
- Runtime hot reload.
- Multiple effects per node.
- Multiple prerequisites or converging graph dependencies.
- Shared/account-wide XP.
- Role unlocking through node purchases.
- Broader balance design and final release economy.
- Per-role revision reconciliation and exact XP refunds.
- Hero-wide progression reset and refund operations.
