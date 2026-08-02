extends CombatantPresentation
class_name CardCombatantPresentation

var card: ActorCard


func _ready() -> void:
	card = get_parent() as ActorCard


func setup_view(value: BattleCombatant) -> void:
	assert(is_instance_valid(card), "CardCombatantPresentation requires an ActorCard parent.")
	if card is HeroCard:
		assert(value is HeroCombatant, "HeroCard requires a HeroCombatant.")
		(card as HeroCard).setup_from_combatant(value as HeroCombatant)
	elif card is EnemyCard:
		assert(value is EnemyCombatant, "EnemyCard requires an EnemyCombatant.")
		(card as EnemyCard).setup_from_combatant(value as EnemyCombatant)
	else:
		card.bind_combatant(value)


func bind(value: BattleCombatant) -> void:
	super.bind(value)
	if not card.target_hovered.is_connected(_on_card_target_hovered):
		card.target_hovered.connect(_on_card_target_hovered)
	if not card.target_unhovered.is_connected(_on_card_target_unhovered):
		card.target_unhovered.connect(_on_card_target_unhovered)
	if not card.spawn_particles.is_connected(_on_card_particles_requested):
		card.spawn_particles.connect(_on_card_particles_requested)
	if card is HeroCard:
		var hero_card := card as HeroCard
		if not hero_card.hero_clicked.is_connected(_on_hero_card_clicked):
			hero_card.hero_clicked.connect(_on_hero_card_clicked)
	elif card is EnemyCard:
		var enemy_card := card as EnemyCard
		if not enemy_card.enemy_clicked.is_connected(_on_enemy_card_clicked):
			enemy_card.enemy_clicked.connect(_on_enemy_card_clicked)


func _on_card_target_hovered(_card: ActorCard) -> void:
	target_hovered.emit(combatant)


func _on_card_target_unhovered(_card: ActorCard) -> void:
	target_unhovered.emit(combatant)


func _on_hero_card_clicked(_card: HeroCard) -> void:
	target_pressed.emit(combatant)


func _on_enemy_card_clicked(_card: EnemyCard) -> void:
	target_pressed.emit(combatant)


func _on_card_particles_requested(position: Vector2, type: String) -> void:
	particles_requested.emit(position, type)


func get_target_screen_position() -> Vector2:
	return card.get_global_rect().get_center() if is_instance_valid(card) else Vector2.ZERO


func is_target_visible() -> bool:
	return is_instance_valid(card) and card.is_visible_in_tree()


func set_target_presentation(state: TargetState) -> void:
	super.set_target_presentation(state)
	if not is_instance_valid(card):
		return
	match state:
		TargetState.NORMAL:
			card.set_target_presentation(ActorCard.TargetPresentation.NORMAL)
		TargetState.AVAILABLE:
			card.set_target_presentation(ActorCard.TargetPresentation.AVAILABLE)
		TargetState.SELECTED:
			card.set_target_presentation(ActorCard.TargetPresentation.SELECTED)


func set_acting(active: bool) -> void:
	super.set_acting(active)
	if not is_instance_valid(card):
		return
	if card is HeroCard:
		if active:
			await (card as HeroCard)._slide_up()
		else:
			await (card as HeroCard)._slide_down()
	card.highlight(active)


func show_action(action_name: String) -> void:
	card.show_action(action_name)


func hide_action() -> void:
	card.hide_action()


func sync_visual_health() -> Tween:
	return card.sync_visual_health()


func refresh_intent() -> void:
	if card is EnemyCard:
		(card as EnemyCard).refresh_intent_presentation()
