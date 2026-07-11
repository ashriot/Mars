# Valid Component Loot Design

## Goal

Component reward generation must always return an `InventoryItem` ID that exists in `ItemDatabase` and has `ItemCategory.COMPONENT`.

## Root Cause

`LootManager` currently constructs component IDs from random equipment type, dungeon tier, and rarity. The content database contains only `comp_weap_1_common` and `comp_weap_1_rare`, so generated armor and higher-tier IDs fail the strict reward-payload validator.

## Design

`ItemDatabase` will track registered component IDs while scanning resources and expose a component-selection method. Selection will prefer resources matching the requested tier and rarity. If no exact match exists, it will fall back to an existing component rather than synthesize an unknown ID.

To keep current rarity behavior predictable, a requested rare drop will prefer a rare component and a common drop will prefer a common component. Tier is the next preference. When content does not cover the requested combination, any registered component is valid. No armor or higher-tier resources will be added as part of stabilization.

`LootManager._generate_loot_data()` will use the selected registered ID for component rewards. If the database contains no components, generation will return an empty dictionary and report an error rather than create an invalid payload.

The reward validator remains unchanged and continues rejecting unknown or category-mismatched IDs.

## Verification

Automated tests will verify:

1. Every registered component ID resolves to a component resource.
2. Tier-1 common and rare requests prefer their matching resources.
3. Unsupported armor/higher-tier combinations fall back to a registered component.
4. Generated component payloads pass `DungeonSaveCodec.is_valid_reward_payload()`.
5. An empty component registry cannot produce a fabricated ID.

The complete GUT suite and headless editor parse check must pass. Test execution remains isolated from production save data.

## Scope

This fixes component reward validity only. It does not add content, change drop probabilities, loosen payload validation, or refactor the broader loot system.
