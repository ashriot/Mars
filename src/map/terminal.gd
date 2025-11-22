extends Control

# Define a custom signal so the Manager knows when a choice is made
signal option_selected(choice_index)
signal closed

@onready var close_button: TextureButton = $Panel/ColorRect/CloseButton
@onready var text_label: RichTextLabel = $Panel/Label

# This is your template. Note the {keys} inside the text.
# We use [url] tags to make the options clickable!
const TERMINAL_TEXT = """=========================================
PARADIGM TERMINAL v4.2 - {facility}
=========================================
Neural Auth: [color=green][SUCCESS - GUEST OVERRIDE][/color]
Firewall: [color=red]DISABLED [ADMIN BYPASS DETECTED][/color]
Session ID: {session_id}

$ pwd
/usr/local/paradigm/secops/terminals/alpha_7

$ /.bit-wallet: echo_virai_0x742f... [LINKED]
$ clear

[b]--- ACCESS GRANTED ---
PLEASE MAKE YOUR SELECTION:

[url=opt_1]1 -> RECEIVE [{bits}] BITS (CREDIT TRANSFER)[/url]
[url=opt_2]2 -> REDUCE ALERT LEVEL BY {alert}% (PATROL PURGE)[/url]

ENTER CHOICE [1-2]: _[/b]

[color=#666666][SECURITY LOG: Unauthorized access logged. Purge in T-30s.][/color]"""

var type_tween: Tween

func _ready():
	# Connect the RichTextLabel's "meta_clicked" signal
	# This detects when you click the [url] text
	text_label.meta_clicked.connect(_on_text_link_clicked)

	# If testing alone, call setup manually:
	# setup("OMEGA WING", 100, 50)

func setup(facility_name: String, bits_amount: int, alert_amount: int):
	# 1. Generate a random fake session ID for flavor
	var session = "0x%X-%d-KANECHO" % [randi() % 0xFFFF, randi() % 9999]

	# 2. Create the data dictionary
	var data = {
		"facility": facility_name,
		"session_id": session,
		"bits": str(bits_amount),
		"alert": str(alert_amount)
	}

	# 3. Format the text
	text_label.text = TERMINAL_TEXT.format(data)

	# 4. Start the typing animation
	_start_typing_effect()

func _start_typing_effect():
	# Calculate duration based on text length (faster typing for longer text)
	var char_count = text_label.get_total_character_count()
	var duration = float(char_count) * 0.001 # 0.01 seconds per character

	text_label.visible_ratio = 0.0

	# Play sound (optional loop handling would go here)
	AudioManager.play_sfx("terminal")

	if type_tween and type_tween.is_running():
		type_tween.kill()

	type_tween = create_tween()
	type_tween.tween_property(text_label, "visible_ratio", 1.0, duration)

# This handles clicks on the text options "1 -> ..." and "2 -> ..."
func _on_text_link_clicked(meta):
	if meta == "opt_1":
		print("Selected Option 1: Bits")
		option_selected.emit(1)
		_animate_close()
	elif meta == "opt_2":
		print("Selected Option 2: Alert")
		option_selected.emit(2)
		_animate_close()

func _on_close_button_pressed() -> void:
	_animate_close()

func _animate_close():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	await tween.finished
	hide()
	closed.emit()
