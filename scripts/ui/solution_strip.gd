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

var board_def: BoardDefinition
var solution: PuzzleSolution
var is_revealed: bool = false

func set_solution(p_solution: PuzzleSolution, p_board_def: BoardDefinition) -> void:
	self.solution = p_solution
	self.board_def = p_board_def
	queue_redraw()

func set_revealed(p_revealed: bool) -> void:
	self.is_revealed = p_revealed
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
		var action := solution.get_action(t)
		var shape: ShapeInstance = action.shape_instance if action != null else null

		if shape != null:
			order += 1

		_draw_cell(rect, shape, order if shape != null else 0)

func _draw_cell(rect: Rect2, shape: ShapeInstance, order: int) -> void:
	draw_rect(rect, COLOR_CELL_BG)
	draw_rect(rect, COLOR_CELL_BORDER, false, 1.0)

	var pad := rect.size.x * 0.14
	var face := Rect2(
		rect.position.x + pad,
		rect.position.y + pad,
		rect.size.x - pad * 2.0,
		rect.size.x - pad * 2.0
	)
	var center := face.position + face.size * 0.5
	var scale_factor := (face.size.x * 0.5) / board_def.radius

	if shape == null:
		_draw_skip(center, board_def.radius * scale_factor)
		return

	_draw_field(center, scale_factor, shape)
	_draw_shape(center, scale_factor, shape)
	_draw_order_pips(rect, order)

# A dashed ring means "this turn is a deliberate skip", not "nothing planned here".
func _draw_skip(center: Vector2, radius: float) -> void:
	var segments := 10
	for i in range(segments):
		if i % 2 == 1:
			continue
		var a0 := TAU * (float(i) / float(segments))
		var a1 := TAU * (float(i + 1) / float(segments))
		draw_arc(center, radius, a0, a1, 4, COLOR_SKIP, 2.0)

func _draw_field(center: Vector2, scale_factor: float, shape: ShapeInstance) -> void:
	draw_arc(center, board_def.radius * scale_factor, 0, TAU, 32, COLOR_FIELD, 1.0)

	for i in range(board_def.node_count):
		var pos := center + (board_def.get_node_position(i) - board_def.center) * scale_factor
		var used := shape.node_ids.has(i)
		draw_circle(pos, 3.0 if used else 2.0, COLOR_DOT_USED if used else COLOR_DOT)

func _draw_shape(center: Vector2, scale_factor: float, shape: ShapeInstance) -> void:
	if shape.geometry == null:
		return

	for seg in shape.geometry.segments:
		var p1 := center + (seg.p1 - board_def.center) * scale_factor
		var p2 := center + (seg.p2 - board_def.center) * scale_factor
		draw_line(p1, p2, COLOR_INK, 2.0)

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
