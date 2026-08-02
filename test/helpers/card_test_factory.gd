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
