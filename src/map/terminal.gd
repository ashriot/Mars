extends Control

signal option_selected(choice_id, value) # Generic signal
signal closed

@onready var close_button: TextureButton = $Panel/ColorRect/CloseButton
@onready var text_label: RichTextLabel = $Panel/Label

var type_tween: Tween
var cursor_tween: Tween
var final_text_content: String = ""

# Data for the logic handler
var current_terminal_index: int = 0
var base_bits: int = 0
var base_alert_reduction: int = 0

func _ready():
	text_label.meta_clicked.connect(_on_text_link_clicked)

func setup(data: Dictionary):
	var upgrade_key = data.upgrade_key
	var bits_val = data.bits
	var alert_val = data.alert
	var facility_name = data.facility_name
	var session = data.session_id
	if session == "": session = "0x%X-%d-KANECHO" % [randi() % 0xFFFF, randi() % 9999]

	# 2. CALCULATE UPGRADES (0=Security, 1=Medical, 2=Finance)
	var opt_sec = _get_security_text(upgrade_key == "security", alert_val)
	var opt_scan = _get_scan_text(upgrade_key == "scan")
	var opt_med = _get_medical_text(upgrade_key == "medical")
	var opt_fin = _get_finance_text(upgrade_key == "finance", bits_val)

	# --- 2. BUILD TEXT ---
	var text_body = """=========================================
PARADIGM TERMINAL v4.2 - {facility}
=========================================
Neural Auth: [color=#00ff00][SUCCESS][/color] | Firewall: [color=red][OFF][/color]
Session ID: {session}

--- ACCESS GRANTED ---
SELECT PROTOCOL:[b]

{opt_1}
{opt_2}
{opt_3}
{opt_4}
{opt_5}

ENTER CHOICE [1-4]: _[/b]
[color=#666666][SECURITY: Trace detected. Purge in T-30s.][/color]"""

	var format_data = {
		"facility": facility_name,
		"session": session,
		"opt_1": opt_sec,
		"opt_2": opt_scan,
		"opt_3": opt_med,
		"opt_4": opt_fin,
		"opt_5": "[url=opt_extract]4 -> SIGNAL EXTRACTION (TACTICAL RETREAT)[/url]"
	}

	final_text_content = text_body.format(format_data)
	text_label.text = final_text_content
	_start_typing_effect()

# --- HELPERS FOR TEXT GENERATION ---
func _get_security_text(is_upgraded: bool, amount: int) -> String:
	var suffix = " [color=gold][UPGRADED][/color]" if is_upgraded else ""
	var label = "REBOOT SECURITY" if is_upgraded else "SCRAMBLE CAMERAS"
	var tag = "opt_sec_up" if is_upgraded else "opt_sec"
	return "[url=%s]1 -> %s (ALERT -%d%%)[/url]%s" % [tag, label, amount, suffix]

func _get_scan_text(is_upgraded: bool) -> String:

	if is_upgraded:
		return "[url=opt_scan_up]2 -> HIJACK CAMERA NETWORK (WIDE SCAN)[/url] [color=gold][UPGRADED][/color]"
	else:
		return "[url=opt_scan]2 -> HIJACK LOCAL FEED (SECTOR SCAN)[/url]"

func _get_finance_text(is_upgraded: bool, amount: int) -> String:
	var suffix = " [color=gold][UPGRADED][/color]" if is_upgraded else ""
	var label = "INTERCEPT PAYMENT" if is_upgraded else "BIT MINE"
	var tag = "opt_fin_up" if is_upgraded else "opt_fin"
	var display_val = float(amount) / 10.0
	return "[url=%s]3 -> %s (+%.1f BITS)[/url]%s" % [tag, label, display_val, suffix]

func _get_medical_text(is_upgraded: bool) -> String:
	if is_upgraded:
		return "[url=opt_med_up]2 -> DISPENSE ADRENALINE (HEAL + BOOST)[/url] [color=gold][UPGRADED][/color]"
	else:
		return "[url=opt_med]2 -> DISPENSE PAINKILLERS (HEAL INJURY)[/url]"

func _on_text_link_clicked(meta):
	var meta_str = str(meta)
	AudioManager.play_sfx("terminal")

	option_selected.emit(meta_str)
	_animate_close()

func _start_typing_effect():
	# Stop any existing cursor blinking
	if cursor_tween: cursor_tween.kill()

	var char_count = text_label.get_total_character_count()
	var duration = float(char_count) * 0.001

	text_label.visible_ratio = 0.0

	if type_tween and type_tween.is_running():
		type_tween.kill()

	type_tween = create_tween()
	type_tween.tween_property(text_label, "visible_ratio", 1.0, duration)

func _animate_close():
	if cursor_tween: cursor_tween.kill()
	text_label.text = final_text_content
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	await tween.finished
	hide()
	closed.emit()

func _on_close_button_pressed() -> void:
	_animate_close()
