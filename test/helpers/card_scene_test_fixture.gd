extends RefCounted

const HeroCardScene := preload("res://src/battle/hero_card.tscn")
const EnemyCardScene := preload("res://src/battle/enemy_card.tscn")


static func bind(
	parent: Node,
	card: ActorCard,
	faction: BattleCombatant.Faction = BattleCombatant.Faction.HERO,
	stats: ActorStats = null,
	manager: BattleManager = null,
	combatant_override: BattleCombatant = null,
) -> ActorCard:
	_ensure_scene_backing(card, faction)
	if card.get_parent() == null:
		parent.add_child(card)
	assert(card.is_node_ready(), "card fixture must enter the scene tree before binding")
	var combatant := combatant_override
	if combatant != null:
		assert(
			(card is HeroCard and combatant is HeroCombatant) \
				or (card is EnemyCard and combatant is EnemyCombatant) \
				or not card is HeroCard and not card is EnemyCard,
			"specialized cards require matching specialized combatants",
		)
	elif card is HeroCard:
		combatant = HeroCombatant.new()
	elif card is EnemyCard:
		combatant = EnemyCombatant.new()
	else:
		combatant = HeroCombatant.new() \
			if faction == BattleCombatant.Faction.HERO else EnemyCombatant.new()
	card.add_child(combatant)
	combatant.setup_base(stats if stats != null else ActorStats.new(), faction, manager)
	card.battle_manager = manager
	card.bind_combatant(combatant)
	return card


static func actor(
	parent: Node,
	faction: BattleCombatant.Faction = BattleCombatant.Faction.HERO,
	stats: ActorStats = null,
	manager: BattleManager = null,
) -> ActorCard:
	return bind(parent, ActorCard.new(), faction, stats, manager)


static func hero(
	parent: Node,
	stats: ActorStats = null,
	manager: BattleManager = null,
) -> HeroCard:
	return bind(
		parent, HeroCardScene.instantiate() as HeroCard,
		BattleCombatant.Faction.HERO, stats, manager,
	) as HeroCard


static func enemy(
	parent: Node,
	stats: ActorStats = null,
	manager: BattleManager = null,
) -> EnemyCard:
	return bind(
		parent, EnemyCardScene.instantiate() as EnemyCard,
		BattleCombatant.Faction.ENEMY, stats, manager,
	) as EnemyCard


static func _ensure_scene_backing(
	card: ActorCard,
	faction: BattleCombatant.Faction,
) -> void:
	if card.get_node_or_null("CombatantPresentation") != null:
		return
	var source_scene := HeroCardScene \
		if faction == BattleCombatant.Faction.HERO else EnemyCardScene
	var source := source_scene.instantiate() as ActorCard
	card.damage_popup_scene = source.damage_popup_scene
	card.buff_scene = source.buff_scene
	card.debuff_scene = source.debuff_scene
	while source.get_child_count() > 0:
		var child := source.get_child(0)
		source.remove_child(child)
		_clear_scene_owners(child)
		card.add_child(child)
	source.free()


static func _clear_scene_owners(node: Node) -> void:
	node.owner = null
	for child: Node in node.get_children():
		_clear_scene_owners(child)
