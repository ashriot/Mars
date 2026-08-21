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

## Current amount. WRAPPED treats this as an integer hit count: rounded
## half-away-from-zero (0.5 -> 1, 2.5 -> 3) before being clamped into cells.
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

## TALLY only. Insert group_gap every N cells so the eye subitises in fives
## instead of counting. 0 disables grouping.
@export var group_every: int = 0:
	set(v):
		group_every = maxi(v, 0)
		queue_redraw()
		update_minimum_size()

@export var group_gap: float = 10.5:
	set(v):
		group_gap = v
		queue_redraw()
		update_minimum_size()

## WRAPPED only. One cell equals one hit at a CONSTANT size — never rescale
## cells to fit a bigger ceiling. The gauge wraps instead: max_value cells
## laid out per_row at a time. Row count then IS the cap, so nothing can
## overfill a bar whose ceiling you cannot see. Minimum-size width always
## reserves the full per_row columns, even when the cap doesn't fill a
## row — a cap of 3 is exactly as wide as a cap of 10 or 30, so the
## widget's width is identical for every unit regardless of its guard cap.
## The one exception is a cap of 0 (no guard mechanic at all), which
## collapses to Vector2.ZERO instead of drawing a phantom empty cell — see
## get_row_count().
@export var per_row: int = 10:
	set(v):
		per_row = maxi(v, 1)
		queue_redraw()
		update_minimum_size()

@export var row_gap: float = 3.0:
	set(v):
		row_gap = v
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
## WRAPPED fills one cell per point of max_value with integer fill instead
## (see _build_wrapped_quads), and does not call this.
func get_full_cell_count() -> int:
	return floori(get_ratio() * float(cells))


## Fractional fill, in [0, 1), of the single leading cell the PIPS fill
## model leaves partial — see get_full_cell_count(). WRAPPED does not call
## this either.
func get_partial_cell_fill() -> float:
	var exact := get_ratio() * float(cells)
	return exact - float(floori(exact))


func _get_minimum_size() -> Vector2:
	if style == Style.WRAPPED:
		var rows := get_row_count()
		if rows == 0:
			return Vector2.ZERO
		var width := per_row * cell_size.x + maxf(per_row - 1, 0) * cell_gap + absf(skew_px)
		var height := rows * cell_size.y + maxf(rows - 1, 0) * row_gap
		return Vector2(width, height)

	var width := cells * cell_size.x + maxf(cells - 1, 0) * cell_gap
	if style == Style.TALLY and group_every > 0:
		width += group_gap * floorf(float(cells - 1) / float(group_every))
	return Vector2(width + absf(skew_px), cell_size.y)


## WRAPPED only. Row count IS the cap: max_value cells laid out per_row at a
## time, so a bar's row count (and therefore height) is fixed by its ceiling
## alone, never by the live value. A cap of 0 (or negative) has no cells at
## all and reports 0 rows, not 1 — see _wrapped_cell_count(). Other styles
## are single-row.
func get_row_count() -> int:
	if style != Style.WRAPPED:
		return 1
	var count := _wrapped_cell_count()
	if count == 0:
		return 0
	return ceili(float(count) / float(per_row))


## WRAPPED cell count: one cell per point of max_value, floored at 0 (not 1)
## so a unit with no guard mechanic (max_value <= 0) collapses to no cells
## instead of drawing one phantom empty cell. Shared by get_row_count() and
## _build_wrapped_quads() so the two derivations can't drift apart.
func _wrapped_cell_count() -> int:
	return maxi(int(round(max_value)), 0)


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


## Translates every point of a quad by offset. Static and pure, used to move
## a cell-local quad (built with y in [0, cell_size.y]) down into its row.
static func _translate_quad(quad: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in quad:
		out.append(point + offset)
	return out


func _quad(x: float, y0: float, y1: float, w: float) -> PackedVector2Array:
	return build_quad(x, y0, y1, w, cell_size.y, skew_px)


func _stroke(quad: PackedVector2Array, col: Color, width: float = 1.0) -> void:
	var loop := quad.duplicate()
	loop.append(quad[0])
	draw_polyline(loop, col, width, false)


## Every quad this bar would draw for its current state, in draw order,
## as { quad: PackedVector2Array, kind: StringName } dictionaries. kind is
## &"track", &"fill", or &"waterline". _draw() paints exactly this list;
## tests read it, so layout coverage is the real layout, not a parallel
## derivation.
func get_draw_quads() -> Array[Dictionary]:
	var pad := left_pad(skew_px)
	if style == Style.WRAPPED:
		return _build_wrapped_quads(pad)
	return _build_pips_quads(pad)


func _build_pips_quads(pad: float) -> Array[Dictionary]:
	var quads: Array[Dictionary] = []
	var h := cell_size.y
	var w := cell_size.x
	var full := get_full_cell_count()
	var frac := get_partial_cell_fill()
	var x := pad

	for i in cells:
		if style == Style.TALLY and group_every > 0 and i > 0 and i % group_every == 0:
			x += group_gap

		var fill := 0.0
		var partial := false
		if i < full:
			fill = 1.0
		elif i == full and frac > PARTIAL_CELL_EPSILON:
			fill = frac
			partial = true

		quads.append({quad = _quad(x, 0.0, h, w), kind = &"track"})

		if fill > 0.0:
			var top := h * (1.0 - fill)
			quads.append({quad = _quad(x, top, h, w), kind = &"fill"})
			if partial:
				var edge_bottom := minf(top + waterline_px, h)
				quads.append({quad = _quad(x, top, edge_bottom, w), kind = &"waterline"})

		x += w + cell_gap

	return quads


## WRAPPED: one cell per point of max_value, at constant cell_size, wrapped
## per_row per line — filled from the first cell forward. No partial cell,
## no waterline in this style.
func _build_wrapped_quads(pad: float) -> Array[Dictionary]:
	var quads: Array[Dictionary] = []
	var h := cell_size.y
	var w := cell_size.x
	var count := _wrapped_cell_count()
	var filled := clampi(int(round(value)), 0, count)

	for i in count:
		var row := i / per_row
		var column := i % per_row
		var x := pad + column * (w + cell_gap)
		var offset := Vector2(0.0, row * (h + row_gap))

		# track and fill share one built quad instead of building the same
		# geometry twice. Safe because nothing mutates the returned quads —
		# _draw() only reads them and _stroke() duplicates before appending.
		# The two entries alias one buffer: an in-place edit to either
		# (quad[i] = ...) would move the other. Rebuild rather than edit.
		var cell_quad := _translate_quad(_quad(x, 0.0, h, w), offset)
		quads.append({quad = cell_quad, kind = &"track"})
		if i < filled:
			quads.append({quad = cell_quad, kind = &"fill"})

	return quads


func _draw() -> void:
	# The fill and track polygons stay exactly inside
	# [0, get_minimum_size().x] at any skew sign — see left_pad(). The 1px
	# track-line stroke drawn over that boundary is centred on it, though,
	# so its ink overhangs by ~0.5px; that's cosmetic at 1px/11% alpha and
	# left as-is.
	for entry in get_draw_quads():
		var quad: PackedVector2Array = entry.quad
		match entry.kind:
			&"track":
				if track_fill.a > 0.0:
					draw_colored_polygon(quad, track_fill)
				if track_line.a > 0.0:
					_stroke(quad, track_line)
			&"fill":
				draw_colored_polygon(quad, fill_color)
			&"waterline":
				if waterline.a > 0.0:
					draw_colored_polygon(quad, waterline)
