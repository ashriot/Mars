@tool
class_name SegmentBar
extends Control

## Draws every discrete bar in the combat HUD: HP pips, the guard gauge,
## the focus tally and ability cost. Pure polygon drawing — no textures,
## no nine-patches, no shaders — so cell count, size, gap, skew and colour
## stay live-editable and nothing needs re-exporting from an art tool.

enum Style {
	PIPS,    ## N skewed cells, fill grows bottom-up, leading cell shows the fraction.
	WRAPPED, ## max_value cells at constant size, wrapped per_row per line.
	TALLY,   ## N cells grouped every group_every, read as tally marks.
}

@export var style: Style = Style.PIPS:
	set(v):
		style = v
		queue_redraw()
		update_minimum_size()

@export var value: float = 100.0:
	set(v):
		value = v
		queue_redraw()

@export var max_value: float = 100.0:
	set(v):
		max_value = v
		queue_redraw()

@export_group("Layout")
@export var cells: int = 10:
	set(v):
		cells = maxi(v, 1)
		queue_redraw()
		update_minimum_size()

@export var cell_size := Vector2(21, 36):
	set(v):
		cell_size = Vector2(maxf(v.x, 0.0), maxf(v.y, 0.001))
		queue_redraw()
		update_minimum_size()

@export var cell_gap: float = 4.5:
	set(v):
		cell_gap = v
		queue_redraw()
		update_minimum_size()

## Horizontal shear across the full cell height, in pixels. 0 for square cells.
@export var skew_px: float = 6.45:
	set(v):
		skew_px = v
		queue_redraw()
		update_minimum_size()

@export_group("Colour")
@export var fill_color := Color("a2b6ca")
@export var track_fill := Color(1, 1, 1, 0.055)
@export var track_line := Color(1, 1, 1, 0.11)
## Bright edge on the partially drained cell. Alpha 0 disables it.
@export var waterline := Color("f0f5fa", 0.9)
@export var waterline_px: float = 3.0


## Named so it isn't confused with any other tolerance in this file — the
## max_value setter used to carry its own floor of the same magnitude.
const PARTIAL_CELL_EPSILON := 0.001


func get_ratio() -> float:
	return clampf(value / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0


## Full cell count under the PIPS fill model: get_ratio() scaled to cell
## count and floored, so cells fill left-to-right as one continuous ramp.
## WRAPPED (Task 5) fills one cell per point of max_value with integer
## fill instead, and does not call this.
func get_full_cell_count() -> int:
	return floori(get_ratio() * float(cells))


## Fractional fill, in [0, 1), of the single leading cell the PIPS fill
## model leaves partial — see get_full_cell_count(). WRAPPED does not call
## this either.
func get_partial_cell_fill() -> float:
	var exact := get_ratio() * float(cells)
	return exact - float(floori(exact))


func _get_minimum_size() -> Vector2:
	var width := cells * cell_size.x + maxf(cells - 1, 0) * cell_gap
	return Vector2(width + absf(skew_px), cell_size.y)


## Left padding that keeps every cell's polygon inside [0, get_minimum_size().x]
## regardless of skew's sign: positive skew pushes a cell's top-right corner
## past the unpadded width, negative skew pushes its top-left corner past
## x = 0, and both need the same magnitude of padding to compensate. Static
## and pure so tests can pin the exact value without a draw context.
static func left_pad(skew: float) -> float:
	return absf(skew) * 0.5


## Builds a sheared quad. y0 and y1 are measured from the top of the cell,
## so a partial fill is a quad from h * (1 - fill) down to h. Static and
## pure so tests can assert exact corner points without a draw context.
static func build_quad(x: float, y0: float, y1: float, w: float, h: float, skew: float) -> PackedVector2Array:
	var o0 := skew * (0.5 - y0 / h)
	var o1 := skew * (0.5 - y1 / h)
	return PackedVector2Array([
		Vector2(x + o0, y0),
		Vector2(x + o0 + w, y0),
		Vector2(x + o1 + w, y1),
		Vector2(x + o1, y1),
	])


func _quad(x: float, y0: float, y1: float, w: float) -> PackedVector2Array:
	return build_quad(x, y0, y1, w, cell_size.y, skew_px)


func _stroke(quad: PackedVector2Array, col: Color, width: float = 1.0) -> void:
	var loop := quad.duplicate()
	loop.append(quad[0])
	draw_polyline(loop, col, width, false)


func _draw() -> void:
	# The fill and track polygons stay exactly inside
	# [0, get_minimum_size().x] at any skew sign — see left_pad(). The 1px
	# track-line stroke drawn over that boundary is centred on it, though,
	# so its ink overhangs by ~0.5px; that's cosmetic at 1px/11% alpha and
	# left as-is.
	_draw_cells(left_pad(skew_px))


func _draw_cells(pad: float) -> void:
	var h := cell_size.y
	var w := cell_size.x
	var full := get_full_cell_count()
	var frac := get_partial_cell_fill()
	var x := pad

	for i in cells:
		var fill := 0.0
		var partial := false
		if i < full:
			fill = 1.0
		elif i == full and frac > PARTIAL_CELL_EPSILON:
			fill = frac
			partial = true

		var track := _quad(x, 0.0, h, w)
		if track_fill.a > 0.0:
			draw_colored_polygon(track, track_fill)
		if track_line.a > 0.0:
			_stroke(track, track_line)

		if fill > 0.0:
			var top := h * (1.0 - fill)
			draw_colored_polygon(_quad(x, top, h, w), fill_color)
			if partial and waterline.a > 0.0:
				var edge := _quad(x, top, minf(top + waterline_px, h), w)
				draw_colored_polygon(edge, waterline)

		x += w + cell_gap
