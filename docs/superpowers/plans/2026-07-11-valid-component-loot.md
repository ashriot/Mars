# Valid Component Loot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate component reward payloads exclusively from component resources registered in `ItemDatabase`.

**Architecture:** `ItemDatabase` owns component discovery and preference-based selection because it already owns the resource registry. `LootManager` requests a valid component ID instead of constructing one, while `DungeonSaveCodec` remains the strict validation boundary.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1

## Global Constraints

- Do not add component content.
- Do not change loot probabilities.
- Do not loosen reward-payload validation.
- Unsupported tier/type/rarity combinations must fall back to a registered component ID.
- An empty component registry must not fabricate an ID.
- Preserve the user's unrelated dirty `.tres` and `.tscn` files.

---

### Task 1: Select Component Rewards From Registered Resources

**Files:**
- Modify: `src/singletons/item_database.gd`
- Modify: `src/singletons/loot_manager.gd`
- Test: `test/unit/test_loot_manager.gd`

**Interfaces:**
- Produces: `ItemDatabase.get_component_id(tier: int, rarity: InventoryItem.Rarity) -> String`
- Consumes: `ItemDatabase.get_item_resource(id: String) -> Resource`, `DungeonSaveCodec.is_valid_reward_payload(value: Variant) -> bool`

- [ ] **Step 1: Write failing selection and payload tests**

Create `test/unit/test_loot_manager.gd` with tests that assert:

```gdscript
extends GutTest


func test_registered_component_ids_resolve_to_component_resources() -> void:
	for id in ["comp_weap_1_common", "comp_weap_1_rare"]:
		var item := ItemDatabase.get_item_resource(id) as InventoryItem
		assert_not_null(item)
		assert_eq(item.category, InventoryItem.ItemCategory.COMPONENT)


func test_component_selection_prefers_matching_rarity() -> void:
	assert_eq(ItemDatabase.get_component_id(1, InventoryItem.Rarity.COMMON), "comp_weap_1_common")
	assert_eq(ItemDatabase.get_component_id(1, InventoryItem.Rarity.RARE), "comp_weap_1_rare")


func test_unsupported_component_tier_falls_back_to_registered_id() -> void:
	var id := ItemDatabase.get_component_id(5, InventoryItem.Rarity.COMMON)
	var item := ItemDatabase.get_item_resource(id) as InventoryItem
	assert_not_null(item)
	assert_eq(item.category, InventoryItem.ItemCategory.COMPONENT)


func test_generated_component_payload_is_valid_for_unsupported_tier() -> void:
	var payload := LootManager._generate_loot_data(LootManager.LootType.COMPONENT, 5, 0)
	assert_true(DungeonSaveCodec.is_valid_reward_payload(payload))
	var item := ItemDatabase.get_item_resource(payload.id) as InventoryItem
	assert_eq(item.category, InventoryItem.ItemCategory.COMPONENT)
```

Add an empty-registry test by temporarily clearing and restoring the component-ID collection, then assert `_generate_loot_data()` returns `{}` and does not contain an `id`.

- [ ] **Step 2: Run the full suite and verify RED**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gexit
```

Expected: failures because `get_component_id()` and the component collection do not exist; the unsupported-tier payload currently contains an unknown synthesized ID.

- [ ] **Step 3: Track registered component IDs**

In `src/singletons/item_database.gd`, add:

```gdscript
var _component_ids: Array[String] = []
```

Inside `_scan_for_items()`, after registering a resource, append its ID when:

```gdscript
elif res is InventoryItem and res.category == InventoryItem.ItemCategory.COMPONENT:
	_component_ids.append(res.id)
```

Add `get_component_id()` that evaluates the registered component resources in this order:

1. Exact tier and rarity.
2. Matching rarity.
3. First registered component.
4. Empty string when none are registered.

Return IDs only from `_component_ids`; never construct an ID.

- [ ] **Step 4: Generate component payloads from the database**

Replace the component-ID construction in `LootManager._generate_loot_data()` with:

```gdscript
var requested_rarity := (
	InventoryItem.Rarity.RARE
		if rarity_mod >= 2
		else InventoryItem.Rarity.COMMON
)
var id := ItemDatabase.get_component_id(tier, requested_rarity)
if id.is_empty():
	push_error("LootManager: No component resources are registered.")
	return {}

data["id"] = id
data["amount"] = 1
```

Do not change the probability constants or validator.

- [ ] **Step 5: Run tests and verify GREEN**

Run the full GUT command from Step 2. Expected: all existing tests plus the five new loot tests pass with no unexpected errors or leak warnings. The empty-registry test must explicitly expect the `push_error` message.

- [ ] **Step 6: Verify parsing and repository hygiene**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
git diff --check
git status --short
```

Expected: Godot exits 0 without parse failures, `git diff --check` is silent, and only the three task files plus the user's existing dirty scene/audio-layout files are present.

- [ ] **Step 7: Commit**

```bash
git add src/singletons/item_database.gd src/singletons/loot_manager.gd test/unit/test_loot_manager.gd
git commit -m "fix: generate valid component rewards"
```
