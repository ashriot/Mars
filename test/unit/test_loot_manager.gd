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
	var saved_component_ids: Array[String] = ItemDatabase._component_ids.duplicate()
	ItemDatabase._component_ids.clear()

	var payload := LootManager._generate_loot_data(LootManager.LootType.COMPONENT, 1, 0)

	assert_push_error("LootManager: No component resources are registered.")
	assert_eq(payload, {})
	assert_false(payload.has("id"))
	ItemDatabase._component_ids.assign(saved_component_ids)
