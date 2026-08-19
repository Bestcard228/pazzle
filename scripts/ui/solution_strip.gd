class_name SolutionStrip
extends Control

# Reveals the intended solution: one cell per turn, left to right, showing which shape to
# draw and which turns to skip. Cells line up with the TurnTimeline above, so "turn 2 of
# the plan" and "turn 2 of the schedule" are the same column.
#
# Each drawn cell renders the shape on a faint copy of the play field with its input nodes
# lit, because the player's actual action is swiping through those nodes -- showing the
# path is more useful than naming the shape.

const COLOR_CELL_BG := Color(0.14, 0.16, 0.24, 1.0)
const COLOR_CELL_BORDER := Color(0.30, 0.35, 0.45, 0.6)
const COLOR_FIELD := Color(0.45, 0.52, 0.66, 0.25)
const COLOR_DOT := Color(0.40, 0.70, 1.00, 0.35)
const COLOR_DOT_USED := Color(0.20, 0.95, 0.50)
const COLOR_INK := Color(0.95, 0.75, 0.20)
const COLOR_SKIP := Color(0.55, 0.60, 0.72, 0.7)
const COLOR_ORDER := Color(0.95, 0.75, 0.20)

const COLOR_ZONE := Color(1.00, 0.25, 0.30)
const COLOR_ZONE_FIELD := Color(0.45, 0.52, 0.66, 0.5)

var board_def: BoardDefinition
var solution: PuzzleSolution
var is_revealed: bool = false

# ERASE mode: the quarter wiped at the end of each turn. This is the answer in that mode,
# so it is only ever filled in when the player asks to see it -- the shapes above it are
# the given half and are always on show.
var erase_order: Array[int] = []

# Layered puzzles paint a different shape per colour on the same turn, so a cell has to
# show all of them, each in its own ink -- one shape would be a lie about the plan.
var layered_solution: LayeredSolution
var layer_count: int = 1

func set_solution(p_solution: PuzzleSolution, p_board_def: BoardDefinition) -> void:
	self.solution = p_solution
	self.board_def = p_board_def
	queue_redraw()

func set_revealed(p_revealed: bool) -> void:
	self.is_revealed = p_revealed
	queue_redraw()

func set_layered_solution(p_layered: LayeredSolution, p_layer_count: int) -> void:
	self.layered_solution = p_layered
	self.layer_count = p_layer_count
	queue_redraw()

func _uses_layers() -> bool:
	return layer_count > 1 and layered_solution != null

func set_erase_order(p_order: Array[int]) -> void:
	self.erase_order = p_order.duplicate()
	queue_redraw()

func _draw() -> void:
	if not is_revealed or solution == null or board_def == null:
		return

	var turns := solution.get_turn_count()
	if turns <= 0:
		return

	var gap := 6.0
	var cell_w: float = (size.x - gap * (turns - 1)) / float(turns)
	cell_w = min(cell_w, 64.0)
	var total_w: float = cell_w * turns + gap * (turns - 1)
	var x0: float = (size.x - total_w) * 0.5
	var cell_h: float = min(size.y, cell_w * 1.2)
	var y0: float = (size.y - cell_h) * 0.5

	# Running count so each drawn cell can show which shape it is in the order
	var order := 0

	for t in range(turns):
		var rect := Rect2(x0 + t * (cell_w + gap), y0, cell_w, cell_h)
		var draws := false
		var shape: ShapeInstance = null

		if _uses_layers():
			draws = layered_solution.is_draw_turn(t)
		else:
			var action := solution.get_action(t)
			shape = action.shape_instance if action != null else null
			draws = shape != null

		if draws:
			order += 1

		_draw_cell(rect, shape, order if draws else 0, t)

func _draw_cell(rect: Rect2, shape: ShapeInstance, order: int, turn: int) -> void:
	draw_rect(rect, COLOR_CELL_BG)
	draw_rect(rect, COLOR_CELL_BORDER, false, 1.0)

	if turn >= 0 and turn < erase_order.size():
		_draw_zone_badge(rect, erase_order[turn])

	var pad := rect.size.x * 0.14
	var face := Rect2(
		rect.position.x + pad,
		rect.position.y + pad,
		rect.size.x - pad * 2.0,
		rect.size.x - pad * 2.0
	)
	var center := face.position + face.size * 0.5
	var scale_factor := MiniBoard.scale_for(board_def, face.size.x, 0.5)

	if _uses_layers():
		if not layered_solution.is_draw_turn(turn):
			MiniBoard.draw_skip_ring(self, center, MiniBoard.radius(board_def, scale_factor), COLOR_SKIP)
			return
		_draw_layered_field(center, scale_factor, turn)
		_draw_layered_shapes(center, scale_factor, turn)
		_draw_order_pips(rect, order)
		return

	if shape == null:
		MiniBoard.draw_skip_ring(self, center, MiniBoard.radius(board_def, scale_factor), COLOR_SKIP)
		return

	_draw_field(center, scale_factor, shape)
	_draw_shape(center, scale_factor, shape)
	_draw_order_pips(rect, order)

# A dot is lit if any colour uses it, and takes that colour; a dot two colours share is
# drawn in the first of them and sized up so the overlap still reads.
func _draw_layered_field(center: Vector2, scale_factor: float, turn: int) -> void:
	var lit := {}

	for i in range(board_def.node_count):
		var users := 0
		var ink := COLOR_DOT

		for layer in range(layer_count):
			var shape := layered_solution.get_shape(turn, layer)
			if shape != null and shape.node_ids.has(i):
				if users == 0:
					ink = LayerSystem.get_layer_color(layer, layer_count)
				users += 1

		if users > 0:
			lit[i] = {"color": ink, "size": 3.0 if users == 1 else 4.0}

	MiniBoard.draw_field(self, board_def, center, scale_factor, COLOR_FIELD, COLOR_DOT, 2.0, lit)

func _draw_layered_shapes(center: Vector2, scale_factor: float, turn: int) -> void:
	for layer in range(layer_count):
		var shape := layered_solution.get_shape(turn, layer)
		if shape == null:
			continue
		MiniBoard.draw_geometry(self, board_def, center, scale_factor, shape.geometry,
			LayerSystem.get_layer_color(layer, layer_count), 2.0)

func _draw_field(center: Vector2, scale_factor: float, shape: ShapeInstance) -> void:
	var lit := {}
	for node_id in shape.node_ids:
		lit[int(node_id)] = {"color": COLOR_DOT_USED, "size": 3.0}
	MiniBoard.draw_field(self, board_def, center, scale_factor, COLOR_FIELD, COLOR_DOT, 2.0, lit)

func _draw_shape(center: Vector2, scale_factor: float, shape: ShapeInstance) -> void:
	MiniBoard.draw_geometry(self, board_def, center, scale_factor, shape.geometry, COLOR_INK, 2.0)

# The quarter this turn wipes, drawn as the field with that slice taken out of it. It
# sits in the corner of the cell so it reads alongside the shape rather than instead of it.
func _draw_zone_badge(rect: Rect2, zone: int) -> void:
	var r: float = rect.size.x * 0.15
	var center := rect.position + Vector2(rect.size.x - r - 3.0, r + 3.0)

	# The lit slice: a quarter for the wedge eraser, which is what every tier uses
	MiniBoard.draw_wedge(self, center, r, EraserSystem.get_phase_axis(zone),
		Color(COLOR_ZONE.r, COLOR_ZONE.g, COLOR_ZONE.b, 0.55))
	MiniBoard.draw_division_cross(self, center, r, COLOR_ZONE_FIELD)
	draw_arc(center, r, 0, TAU, 20, COLOR_ZONE, 1.5)

# Pips spell out where this shape falls in the drawing order: one pip for the first shape,
# two for the second, and so on.
func _draw_order_pips(rect: Rect2, order: int) -> void:
	if order <= 0:
		return

	var pip_r := 2.5
	var gap := 4.0
	var total := pip_r * 2.0 * order + gap * (order - 1)
	var x := rect.position.x + (rect.size.x - total) * 0.5 + pip_r
	var y := rect.position.y + rect.size.y - pip_r - 4.0

	for i in range(order):
		draw_circle(Vector2(x + i * (pip_r * 2.0 + gap), y), pip_r, COLOR_ORDER)
