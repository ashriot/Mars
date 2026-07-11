extends GutTest

var _saved_component_ids: Array[String]
var _saved_item_registry: Dictionary


func before_each() -> void:
	_saved_component_ids.assign(ItemDatabase._component_ids)
	_saved_item_registry = ItemDatabase._item_registry.duplicate()


func after_each() -> void:
	ItemDatabase._component_ids.assign(_saved_component_ids)
	ItemDatabase._item_registry = _saved_item_registry.duplicate()


func test_registered_component_ids_resolve_to_component_resources() -> void:
	for id in ["comp_weap_1_common", "comp_weap_1_rare"]:
		var item := ItemDatabase.get_item_resource(id) as InventoryItem
		assert_not_null(item)
		assert_eq(item.category, InventoryItem.ItemCategory.COMPONENT)


func test_component_selection_prefers_matching_rarity() -> void:
	assert_eq(ItemDatabase.get_component_id(1, InventoryItem.Rarity.COMMON), "comp_weap_1_common")
	assert_eq(ItemDatabase.get_component_id(1, InventoryItem.Rarity.RARE), "comp_weap_1_rare")


func test_component_rarity_preserves_rare_roll_threshold() -> void:
	assert_eq(LootManager._get_requested_component_rarity(2, 0.75), InventoryItem.Rarity.COMMON)
	assert_eq(LootManager._get_requested_component_rarity(2, 0.750001), InventoryItem.Rarity.RARE)
	assert_eq(LootManager._get_requested_component_rarity(1, 1.0), InventoryItem.Rarity.COMMON)


func test_component_selection_skips_stale_ids() -> void:
	ItemDatabase._component_ids.assign(["missing_component", "comp_weap_1_common"])

	assert_eq(
		ItemDatabase.get_component_id(1, InventoryItem.Rarity.COMMON),
		"comp_weap_1_common"
	)


func test_component_selection_skips_ids_reassigned_to_non_components() -> void:
	ItemDatabase._component_ids.assign(["comp_weap_1_common", "comp_weap_1_rare"])
	ItemDatabase._item_registry["comp_weap_1_common"] = ItemDatabase._item_registry["mat_weap_1"]

	assert_eq(
		ItemDatabase.get_component_id(1, InventoryItem.Rarity.COMMON),
		"comp_weap_1_rare"
	)


func test_unsupported_component_tier_falls_back_to_registered_id() -> void:
	var id: String = ItemDatabase.get_component_id(5, InventoryItem.Rarity.COMMON)
	var item := ItemDatabase.get_item_resource(id) as InventoryItem
	assert_not_null(item)
	assert_eq(item.category, InventoryItem.ItemCategory.COMPONENT)


func test_generated_component_payload_is_valid_for_unsupported_tier() -> void:
	var payload := LootManager._generate_loot_data(LootManager.LootType.COMPONENT, 5, 0)
	assert_true(DungeonSaveCodec.is_valid_reward_payload(payload))
	var item := ItemDatabase.get_item_resource(payload.id) as InventoryItem
	assert_eq(item.category, InventoryItem.ItemCategory.COMPONENT)


func test_component_generation_returns_empty_payload_when_registry_is_empty() -> void:
	ItemDatabase._component_ids.clear()

	var payload := LootManager._generate_loot_data(LootManager.LootType.COMPONENT, 1, 0)

	assert_push_error("LootManager: No component resources are registered.")
	assert_eq(payload, {})
	assert_false(payload.has("id"))
