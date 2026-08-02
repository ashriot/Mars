extends RefCounted


static func bind(
	card: ActorCard,
	faction: BattleCombatant.Faction = BattleCombatant.Faction.HERO,
	stats: ActorStats = null,
	manager: BattleManager = null,
	with_presentation: bool = false,
) -> ActorCard:
	var combatant: BattleCombatant
	if card is HeroCard:
		combatant = HeroCombatant.new()
	elif card is EnemyCard:
		combatant = EnemyCombatant.new()
	else:
		combatant = BattleCombatant.new()
	card.add_child(combatant)
	combatant.setup_base(stats if stats != null else ActorStats.new(), faction, manager)
	card.battle_manager = manager
	card.bind_combatant(combatant, not with_presentation)
	if not with_presentation:
		combatant.hp_changed.connect(
			func(_actor, value, max_value): card.hp_changed.emit(value, max_value)
		)
		combatant.guard_changed.connect(
			func(_actor, value): card.armor_changed.emit(value)
		)
		combatant.conditions_changed.connect(
			func(_actor): card.actor_conditions_changed.emit()
		)
		combatant.breached.connect(
			func(_actor): card.actor_breached.emit(card)
		)
		combatant.defeated.connect(
			func(_actor): card.actor_defeated.emit(card)
		)
		combatant.revived.connect(
			func(_actor): card.actor_revived.emit(card)
		)
	return card


static func actor(
	faction: BattleCombatant.Faction = BattleCombatant.Faction.HERO,
	stats: ActorStats = null,
	manager: BattleManager = null,
) -> ActorCard:
	return bind(ActorCard.new(), faction, stats, manager)


static func hero(
	stats: ActorStats = null,
	manager: BattleManager = null,
) -> HeroCard:
	return bind(
		HeroCard.new(), BattleCombatant.Faction.HERO, stats, manager,
	) as HeroCard


static func enemy(
	stats: ActorStats = null,
	manager: BattleManager = null,
) -> EnemyCard:
	return bind(
		EnemyCard.new(), BattleCombatant.Faction.ENEMY, stats, manager,
	) as EnemyCard
