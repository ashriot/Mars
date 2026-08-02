extends CombatantPresentation
class_name CardCombatantPresentation

var card: ActorCard


func _ready() -> void:
	card = get_parent() as ActorCard


func bind(value: BattleCombatant) -> void:
	super.bind(value)
	card.target_hovered.connect(
		func(_card: ActorCard): target_hovered.emit(combatant)
	)
	card.target_unhovered.connect(
		func(_card: ActorCard): target_unhovered.emit(combatant)
	)
	if card is HeroCard:
		(card as HeroCard).hero_clicked.connect(
			func(_card: HeroCard): target_pressed.emit(combatant)
		)
	elif card is EnemyCard:
		(card as EnemyCard).enemy_clicked.connect(
			func(_card: EnemyCard): target_pressed.emit(combatant)
		)


func get_target_screen_position() -> Vector2:
	return card.get_global_rect().get_center() if is_instance_valid(card) else Vector2.ZERO


func is_target_visible() -> bool:
	return is_instance_valid(card) and card.is_visible_in_tree()


func set_target_presentation(state: TargetState) -> void:
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
	card.highlight(active)


func show_action(action_name: String) -> void:
	card.show_action(action_name)


func hide_action() -> void:
	card.hide_action()


func sync_visual_health() -> Tween:
	return card.sync_visual_health()
