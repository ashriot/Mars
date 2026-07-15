extends Control
class_name ActorQueue


const ITEM_SIZE := Vector2(72, 72)
const ANIMATION_DURATION := 0.3
const COMMITTED_EXIT_DISTANCE := 96.0

@onready var gauge: CTBGauge = $CTBGauge
@onready var role_icon: TextureRect = $Interior/RoleIcon
@onready var enemy_label: Label = $Interior/EnemyLabel

var actor_ref: ActorCard
var occurrence_index := 0
var _move_tween: Tween
var _exit_tween: Tween


func setup(
	actor: ActorCard,
	ticks: int,
	is_current: bool,
	occurrence: int,
	animate_gauge := false,
) -> void:
	actor_ref = actor
	occurrence_index = occurrence
	custom_minimum_size = ITEM_SIZE
	size = ITEM_SIZE
	role_icon.visible = actor is HeroCard
	enemy_label.visible = actor is EnemyCard
	if actor is HeroCard:
		var role := (actor as HeroCard).get_current_role()
		role_icon.texture = role.icon if role else null
		role_icon.self_modulate = role.color if role else Color.WHITE
	else:
		enemy_label.text = enemy_abbreviation(actor.actor_name)
	gauge.configure(
		ticks,
		CTBGauge.Faction.HERO if actor is HeroCard else CTBGauge.Faction.ENEMY,
		is_current,
		animate_gauge,
	)


func animate_to(target_position: Vector2) -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_move_tween.tween_property(self, "position", target_position, ANIMATION_DURATION)


func animate_exit() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	if _exit_tween and _exit_tween.is_valid():
		_exit_tween.kill()
	_exit_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_exit_tween.tween_property(self, "modulate:a", 0.0, ANIMATION_DURATION)
	_exit_tween.tween_callback(queue_free)


func animate_committed_exit() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	if _exit_tween and _exit_tween.is_valid():
		_exit_tween.kill()
	_exit_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_exit_tween.set_parallel(true)
	_exit_tween.tween_property(
		self,
		"position",
		position + Vector2.LEFT * COMMITTED_EXIT_DISTANCE,
		ANIMATION_DURATION,
	)
	_exit_tween.tween_property(self, "modulate:a", 0.0, ANIMATION_DURATION)
	_exit_tween.chain().tween_callback(queue_free)


func prepare_for_reuse() -> void:
	if _exit_tween and _exit_tween.is_valid():
		_exit_tween.kill()
	_exit_tween = null
	modulate.a = 1.0


func cancel_animations() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null
	if _exit_tween and _exit_tween.is_valid():
		_exit_tween.kill()
	_exit_tween = null
	gauge.cancel_animation()


static func enemy_abbreviation(actor_name: String) -> String:
	var words := actor_name.strip_edges().split(" ", false)
	var suffix := ""
	if words.size() > 1 and words[-1].length() == 1:
		suffix = words[-1].to_upper()
		words.remove_at(words.size() - 1)
	var core := ""
	if words.size() == 1:
		core = words[0].left(2).to_upper()
	else:
		for word in words.slice(0, 2):
			core += word.left(1).to_upper()
	return core if suffix.is_empty() else "%s %s" % [core, suffix]
