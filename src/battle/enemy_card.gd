extends ActorCard
class_name EnemyCard

# --- UNIQUE Signals ---
signal enemy_clicked(enemy_card)

@export var recover_action: Action

# --- UNIQUE UI Node References ---
@onready var intent_text: RichTextLabel = $Panel/IntentText
@onready var intent_tooltip: RichTooltip = $Panel/IntentText/RichTooltip
@onready var kin_def_gauge: TextureProgressBar = $Panel/KinDef
@onready var kin_def_value: Label = $Panel/KinDef/Value
@onready var nrg_def_gauge: TextureProgressBar = $Panel/NrgDef
@onready var nrg_def_value: Label = $Panel/NrgDef/Value

# --- UNIQUE Data ---
var enemy_data: EnemyData
var ai_state := EnemyAIRuntimeState.new()
var intended_decision := EnemyDecision.new()
var encounter_seed := 0
var intended_action: Action
var intended_targets: Array[ActorCard]
var intent_flash_tween: Tween


func setup(
	data: EnemyData,
	fight_level: int,
	is_elite: bool,
	is_boss: bool,
	hp_multiplier: float = 1.0,
):
	enemy_data = data.duplicate(true) as EnemyData
	enemy_data.level = fight_level
	enemy_data.calculate_stats()
	$Panel/Info/Text.text = "Rk. " + str(enemy_data.level)
	if is_elite:
		$Panel/Info/Text.text += " ELITE"
		_apply_elite_scaling(enemy_data.stats)
		name_label.modulate = Color.ORANGE_RED
	elif is_boss:
		$Panel/Info/Text.text += " BOSS"
		#_apply_boss_scaling(enemy_data.stats)
		name_label.modulate = Color.MAGENTA
	enemy_data.stats.max_hp = maxi(
		1,
		roundi(enemy_data.stats.max_hp * maxf(hp_multiplier, 1.0)),
	)
	setup_base(enemy_data.stats)
	update_defenses()

	name_label.text = enemy_data.stats.actor_name

	if enemy_data.portrait:
		portrait_rect.texture = enemy_data.portrait

func _apply_elite_scaling(stats: ActorStats):
	stats.max_hp = int(stats.max_hp * 5.0)
	stats.attack = int(stats.attack * 1.15)
	stats.psyche = int(stats.psyche * 1.15)
	stats.speed = int(stats.speed * 1.15)

func initialize_ai(seed_value: int) -> void:
	encounter_seed = seed_value
	ai_state.initialize(enemy_data.abilities)


func decide_intent(context: EnemyAIContext) -> void:
	var next := EnemyDecision.new()
	if is_breached and recover_action != null:
		next.action = recover_action
		next.targets = [self]
		next.reason = "recover_breach"
		next.is_recovery = true
	else:
		next = EnemyDecisionEngine.choose(self, enemy_data.abilities, ai_state, context)
	if not next.is_valid():
		push_error("Enemy '%s' could not produce a valid intent on AI turn %d." % [
			actor_name, ai_state.completed_turns,
		])
		clear_intent()
		return
	intended_decision = next
	intended_action = next.action
	intended_targets.assign(next.targets)
	_update_intent_ui()


func complete_ai_turn(used_ability_id: StringName = &"") -> void:
	ai_state.complete_turn(used_ability_id)


func revalidate_intent_targets(context: EnemyAIContext) -> bool:
	if intended_action == null or intended_decision.is_recovery:
		return false
	var ability := intended_decision.ability
	var rule := intended_decision.rule
	if ability == null or rule == null or rule.selector == null:
		return false
	if rule.selector.targets_are_legal(self, intended_targets, context):
		return false
	var rule_index := ability.rules.find(rule)
	if rule_index < 0:
		return false
	var salt := "%s:%d" % [ability.ability_id, rule_index]
	var next_targets := rule.selector.select(self, ai_state, context, salt)
	if next_targets == intended_targets:
		return false
	intended_decision.targets.assign(next_targets)
	intended_targets.assign(next_targets)
	_update_intent_ui()
	return true

func _update_intent_ui():
	if not intended_action:
		intent_text.text = ""
		return

	if intended_action.effects.is_empty():
		return

	var first_effect = intended_action.effects[0]

	if first_effect is Effect_Damage:
		var damage_effect: Effect_Damage = first_effect
		var resolved_hit_count := damage_effect._resolve_hit_count(self)
		var sequence := DamagePreview.for_plan(
			damage_effect,
			self,
			intended_targets,
			intended_action,
			false,
			battle_manager,
		)
		var damage_bindings: Dictionary
		if sequence.is_complete and not sequence.results.is_empty():
			damage_bindings = damage_effect._get_sequence_bindings(sequence, 28)
		else:
			var context := EffectPresentationContext.new(
				self, null, intended_action,
			)
			damage_bindings = damage_effect.get_presentation(context).bindings
			damage_bindings.damage_type = damage_effect._get_damage_type_icon(
				damage_effect.damage_type, 28,
			)
		var final_text := "%s%s%s %s" % [
			damage_bindings.amount,
			damage_bindings.amount_qualifier,
			damage_bindings.hit_count_text,
			damage_bindings.damage_type,
		]
		if intended_action.target_type == Action.TargetType.RANDOM_ENEMY \
			and resolved_hit_count > 1 \
			and damage_bindings.hit_count_text.is_empty():
			final_text += " (%d hits)" % resolved_hit_count
		if intended_action.effects.size() > 1:
			final_text += " *"

		if intended_targets:
			if intended_targets.size() > 1:
				if intended_action.target_type == Action.TargetType.RANDOM_ENEMY:
					final_text += " RANDOM"
				else:
					final_text += " EVERYONE"
			else:
				var tar = intended_targets[0] as HeroCard
				var col = tar.get_current_role().color.to_html()
				final_text += " [color=" + col + "]" + intended_targets[0].actor_name

		intent_text.text = final_text

	else:
		var final_text = intended_action.action_name
		if intended_targets.size() > 1:
			final_text += " EVERYONE"
		else:
			if intended_targets[0].actor_name != actor_name:
				final_text += " " + intended_targets[0].actor_name

		intent_text.text = final_text
	var tooltip_target: ActorCard = intended_targets[0] \
		if intended_targets.size() == 1 else null
	intent_tooltip.bbcode_text = intended_action.get_rich_description(
		self, tooltip_target, intended_targets, battle_manager,
	)
	flash_intent()

func clear_intent() -> void:
	intended_decision = EnemyDecision.new()
	intended_action = null
	intended_targets = []
	_update_intent_ui()

func breach():
	super.breach()
	update_defenses()

func recover_breach():
	super.recover_breach()
	update_defenses()

func update_defenses():
	var kin_def = enemy_data.stats.kinetic_defense
	var nrg_def = enemy_data.stats.energy_defense
	kin_def_value.text = str(kin_def) + "%"
	nrg_def_value.text = str(nrg_def) + "%"
	kin_def_gauge.value = kin_def
	nrg_def_gauge.value = nrg_def

func defeated():
	super.defeated()
	var tween = create_tween()
	tween.tween_property(
		self,
		"modulate:a", # Animate the alpha
		0.0,          # To fully transparent
		0.25          # Over 0.25 seconds
	).set_trans(Tween.TRANS_SINE)

	await tween.finished
	modulate.a = 0

func flash_intent(duration: float = 0.3):
	duration /= battle_manager.battle_speed

	if intent_flash_tween and intent_flash_tween.is_running():
		intent_flash_tween.kill()

	var flash_color = Color.ORANGE_RED
	var base_color = Color(1.0, 1.0, 1.0)

	intent_flash_tween = create_tween()

	intent_flash_tween.tween_property(intent_text, "modulate",
		flash_color, duration).set_trans(Tween.TRANS_SINE)
	intent_flash_tween.tween_property(intent_text, "modulate",
		base_color, duration).set_trans(Tween.TRANS_SINE)

	await intent_flash_tween.finished

func _on_gui_input(event: InputEvent):
	if event.is_action_pressed("ui_accept"):
		print("Clicked on: ", actor_name)
		enemy_clicked.emit(self)
		get_viewport().set_input_as_handled()
