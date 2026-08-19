@tool
class_name UIPalette
extends Resource

## Every colour battle UI is permitted to use. Nothing in the HUD may
## introduce a colour outside this resource — that rule is what makes the
## HP alarm ramp legible, because it guarantees a hurt unit is the only
## warm thing on screen.

@export_group("Surfaces")
@export var panel := Color("11151c", 0.90)
@export var panel_hi := Color("1d242f", 0.94)

@export_group("Strokes")
@export var stroke := Color("8ca3be", 0.22)
@export var stroke_hi := Color("a0b9d7", 0.44)
## Hostile hairline. Marks rank, never identity.
@export var stroke_warm := Color("c88c78", 0.32)

@export_group("Ink")
@export var ink := Color("cdd8e5")
@export var ink_dim := Color("8493a5")
@export var ink_faint := Color("5a6878")
@export var ink_hi := Color("f0f5fa")

@export_group("Accent")
## Active unit and focus ONLY. Never decoration, never a second meaning.
@export var accent := Color("3fe0ff")

@export_group("HP alarm ramp")
@export var hp_ok := Color("a2b6ca")
@export var hp_warn := Color("f0a63c")
@export var hp_crit := Color("ff4b4b")

@export_group("Other")
## Achromatic on purpose: guard must never compete with the HP ramp.
@export var guard := Color("e8f0f8")
## Lethal forecast only.
@export var threat := Color("e8734a")
