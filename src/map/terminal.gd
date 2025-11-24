extends Control

# Define a custom signal so the Manager knows when a choice is made
signal option_selected(choice_index, amount)
signal closed

@onready var close_button: TextureButton = $Panel/ColorRect/CloseButton
@onready var text_label: RichTextLabel = $Panel/Label

# This is your template. Note the {keys} inside the text.
# We use [url] tags to make the options clickable!
const TERMINAL_TEXT = """=========================================
PARADIGM TERMINAL v4.2 - {facility}
=========================================
Neural Auth: [SUCCESS - GUEST OVERRIDE]
Firewall: DISABLED [ADMIN BYPASS DETECTED]
Session ID: {session_id}

$ pwd
/usr/local/paradigm/secops/terminals/alpha_7

$ /.bit-wallet: echo_virai_0x742f... [LINKED]
$ clear

[b]--- ACCESS GRANTED ---
PLEASE MAKE YOUR SELECTION:

[url=opt_1]1 -> RECEIVE [{bits}] BITS (CREDIT TRANSFER)[/url]
[url=opt_2]2 -> REDUCE ALERT LEVEL BY {alert}% (PATROL PURGE)[/url][/b]

[SECURITY: Unauthorized access logged. Purge in T-30s.]"""

var type_tween: Tween
var cursor_tween: Tween
var final_text_content: String = ""
var bits: int
var alert: int

func _ready():
	text_label.meta_clicked.connect(_on_text_link_clicked)

	# If testing alone, call setup manually:
	# setup("OMEGA WING", 100, 50)

func setup(facility_name: String, bits_amount: int, alert_amount: int, session_id: String = ""):
	var session = session_id
	if session == "":
		session = "0x%X-%d-KANECHO" % [randi() % 0xFFFF, randi() % 9999]

	bits = bits_amount
	alert = alert_amount

	var data = {
		"facility": facility_name,
		"session_id": session,
		"bits": str(float(bits_amount) / 10),
		"alert": str(alert_amount)
	}

	# 2. Store the formatted text, but DON'T set the label yet
	final_text_content = TERMINAL_TEXT.format(data)

	# 3. Set the text to the label
	text_label.text = final_text_content

	# 4. Start typing
	_start_typing_effect()

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

	# When typing is done, start the blink loop
	type_tween.finished.connect(_start_cursor_blink)

func _start_cursor_blink():
	# 1. Ensure we are starting fresh
	if cursor_tween and cursor_tween.is_running():
		cursor_tween.kill()

	cursor_tween = create_tween()
	cursor_tween.set_loops() # Loop infinitely

	var text_on = final_text_content + "_"
	var text_off = final_text_content # or + " " to keep spacing

	# 3. Toggle every 0.5 seconds
	cursor_tween.tween_callback(func(): text_label.text = text_on)
	cursor_tween.tween_interval(0.5)
	cursor_tween.tween_callback(func(): text_label.text = text_off)
	cursor_tween.tween_interval(0.5)

func _animate_close():
	if cursor_tween: cursor_tween.kill()
	text_label.text = final_text_content
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	await tween.finished
	hide()
	closed.emit()

func _on_text_link_clicked(meta):
	if meta == "opt_1":
		print("Selected Option 1: Bits")
		option_selected.emit(1, bits)
		_animate_close()
	elif meta == "opt_2":
		print("Selected Option 2: Alert")
		option_selected.emit(2, alert)
		_animate_close()

func _on_close_button_pressed() -> void:
	_animate_close()
