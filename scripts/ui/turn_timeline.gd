class_name TurnTimeline
extends Control

# One cell per turn, showing whichever half of the puzzle is the given one.
#
# In DRAW mode that is the erasure schedule: the player can read the whole thing off this
# strip instead of being told one zone at a time, which is what makes planning "when to
# draw" possible.
#
# In ERASE mode the schedule is the answer, so showing it would hand the puzzle over. The
# strip flips to the other half instead -- the shape each turn lays down -- and fills the
# zone back in only for turns the player has already committed, which is their own history
# rather than a spoiler.

const COLOR_CELL_BG := Color(0.14, 0.16, 0.24, 1.0)
const COLOR_CELL_BORDER := Color(0.30, 0.35, 0.45, 0.6)
const COLOR_CURRENT := Color(0.40, 0.70, 1.00)
const COLOR_WARN := Color(0.95, 0.30, 0.35)
const COLOR_DRAWN := Color(0.95, 0.75, 0.20)
const COLOR_MINI_BG := Color(0.22, 0.25, 0.34, 1.0)

var board_def: BoardDefinition
var max_turns: int = 4
var current_turn: int = 0
var drawn_turns: Array[bool] = []
var _pulse_t: float = 0.0

const COLOR_SHAPE := Color(0.95, 0.75, 0.20)
const COLOR_DOT := Color(0.40, 0.70, 1.00, 0.45)
const COLOR_SKIP := Color(0.55, 0.60, 0.72, 0.7)

# ERASE mode: draw the given shapes instead of the schedule, and only show the zones the
# player has actually committed.
var shows_shapes: bool = false
var shape_solution: PuzzleSolution
var committed_zones: Array[int] = []

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	_pulse_t += delta
	queue_redraw()

func setup(p_board_def: BoardDefinition, p_max_turns: int) -> void:
	self.board_def = p_board_def
	self.max_turns = max(1, p_max_turns)
	self.current_turn = 0
	drawn_turns.clear()
	for i in range(self.max_turns):
		drawn_turns.append(false)
	queue_redraw()

func set_shape_mode(p_enabled: bool, p_solution: PuzzleSolution) -> void:
	self.shows_shapes = p_enabled
	self.shape_solution = p_solution
	queue_redraw()

func set_committed_zones(p_zones: Array[int]) -> void:
	self.committed_zones = p_zones.duplicate()
	queue_redraw()

func set_progress(p_current_turn: int, p_drawn_turns: Array[bool]) -> void:
	self.current_turn = p_current_turn
	self.drawn_turns = p_drawn_turns.duplicate()
	queue_redraw()

func _draw() -> void:
	if board_def == null or max_turns <= 0:
		return

	var gap := 6.0
	var cell_w: float = (size.x - gap * (max_turns - 1)) / float(max_turns)
	cell_w = min(cell_w, 64.0)
	var total_w: float = cell_w * max_turns + gap * (max_turns - 1)
	var x0: float = (size.x - total_w) * 0.5
	var cell_h: float = min(size.y, cell_w * 1.15)
	var y0: float = (size.y - cell_h) * 0.5

	for t in range(max_turns):
		var rect := Rect2(x0 + t * (cell_w + gap), y0, cell_w, cell_h)
		_draw_cell(rect, t)

func _draw_cell(rect: Rect2, turn: int) -> void:
	var is_past := turn < current_turn
	var is_current := turn == current_turn

	# In shape mode the zone is only known for turns already committed; -1 means "not
	# yours to see yet", and nothing about the schedule is drawn.
	var phase := -1
	if shows_shapes:
		if turn < committed_zones.size():
			phase = committed_zones[turn]
	else:
		phase = EraserSystem.get_phase_for_turn(turn, board_def)

	var dim := 0.35 if is_past else 1.0

	# Cell plate
	draw_rect(rect, Color(COLOR_CELL_BG.r, COLOR_CELL_BG.g, COLOR_CELL_BG.b, dim))

	var border_color := COLOR_CELL_BORDER
	var border_w := 1.0
	if is_current:
		var pulse := 0.5 + 0.5 * sin(_pulse_t * 3.0)
		border_color = Color(COLOR_CURRENT.r, COLOR_CURRENT.g, COLOR_CURRENT.b, lerp(0.6, 1.0, pulse))
		border_w = 3.0
	draw_rect(rect, Color(border_color.r, border_color.g, border_color.b, border_color.a * dim), false, border_w)

	# Mini board showing which half this turn erases
	var pad := rect.size.x * 0.22
	var mini := Rect2(rect.position.x + pad, rect.position.y + pad * 0.8,
		rect.size.x - pad * 2.0, rect.size.x - pad * 2.0)
	draw_rect(mini, Color(COLOR_MINI_BG.r, COLOR_MINI_BG.g, COLOR_MINI_BG.b, dim))

	if phase >= 0:
		var wipe_alpha := 0.9 if is_current else 0.6
		draw_colored_polygon(_phase_sub_polygon(mini, phase),
			Color(COLOR_WARN.r, COLOR_WARN.g, COLOR_WARN.b, wipe_alpha * dim))

		# Division lines so the slice shape reads at a glance
		_draw_division(mini, phase, dim)

	if shows_shapes:
		_draw_turn_shape(mini, turn, dim)
		return

	# Marker for a turn the player committed a shape on
	if turn < drawn_turns.size() and drawn_turns[turn]:
		var dot := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y - 7.0)
		draw_circle(dot, 3.5, Color(COLOR_DRAWN.r, COLOR_DRAWN.g, COLOR_DRAWN.b, dim))

# The shape this turn lays down, on a small copy of the field. A dashed ring means the
# turn draws nothing, which is as much a part of the given plan as the shapes are.
func _draw_turn_shape(mini: Rect2, turn: int, dim: float) -> void:
	if shape_solution == null or board_def == null:
		return

	var action := shape_solution.get_action(turn)
	var shape: ShapeInstance = action.shape_instance if action != null else null
	var center := mini.position + mini.size * 0.5
	var scale_factor := MiniBoard.scale_for(board_def, mini.size.x, 0.46)

	if shape == null:
		MiniBoard.draw_skip_ring(self, center, MiniBoard.radius(board_def, scale_factor),
			Color(COLOR_SKIP.r, COLOR_SKIP.g, COLOR_SKIP.b, COLOR_SKIP.a * dim), 1.5)
		return

	for i in range(board_def.node_count):
		draw_circle(MiniBoard.node_position(board_def, center, scale_factor, i), 1.5,
			Color(COLOR_DOT.r, COLOR_DOT.g, COLOR_DOT.b, COLOR_DOT.a * dim))

	MiniBoard.draw_geometry(self, board_def, center, scale_factor, shape.geometry,
		Color(COLOR_SHAPE.r, COLOR_SHAPE.g, COLOR_SHAPE.b, dim), 1.8)

func _is_wedge_mode() -> bool:
	return board_def != null and board_def.erasure_shape == EraserSystem.ErasureShape.DIAGONAL_WEDGE

# The slice this turn erases: a triangular wedge running to a corner in X mode, or half
# the tile in half-plane mode.
func _phase_sub_polygon(mini: Rect2, phase: int) -> PackedVector2Array:
	var c := mini.position + mini.size * 0.5
	var lo := mini.position
	var hi := mini.position + mini.size

	if _is_wedge_mode():
		match posmod(phase, EraserSystem.PHASE_COUNT):
			EraserSystem.ErasureRegion.TOP:
				return PackedVector2Array([c, lo, Vector2(hi.x, lo.y)])
			EraserSystem.ErasureRegion.RIGHT:
				return PackedVector2Array([c, Vector2(hi.x, lo.y), hi])
			EraserSystem.ErasureRegion.BOTTOM:
				return PackedVector2Array([c, hi, Vector2(lo.x, hi.y)])
			EraserSystem.ErasureRegion.LEFT:
				return PackedVector2Array([c, Vector2(lo.x, hi.y), lo])
			_:
				return PackedVector2Array()

	match posmod(phase, EraserSystem.PHASE_COUNT):
		EraserSystem.ErasureRegion.TOP:
			return PackedVector2Array([lo, Vector2(hi.x, lo.y), Vector2(hi.x, c.y), Vector2(lo.x, c.y)])
		EraserSystem.ErasureRegion.RIGHT:
			return PackedVector2Array([Vector2(c.x, lo.y), Vector2(hi.x, lo.y), hi, Vector2(c.x, hi.y)])
		EraserSystem.ErasureRegion.BOTTOM:
			return PackedVector2Array([Vector2(lo.x, c.y), Vector2(hi.x, c.y), hi, Vector2(lo.x, hi.y)])
		EraserSystem.ErasureRegion.LEFT:
			return PackedVector2Array([lo, Vector2(c.x, lo.y), Vector2(c.x, hi.y), Vector2(lo.x, hi.y)])
		_:
			return PackedVector2Array()

func _draw_division(mini: Rect2, phase: int, dim: float) -> void:
	var c := mini.position + mini.size * 0.5
	var lo := mini.position
	var hi := mini.position + mini.size
	var line_color := Color(1.0, 1.0, 1.0, 0.4 * dim)

	if _is_wedge_mode():
		draw_line(lo, hi, line_color, 1.0)
		draw_line(Vector2(hi.x, lo.y), Vector2(lo.x, hi.y), line_color, 1.0)
		return

	match posmod(phase, EraserSystem.PHASE_COUNT):
		EraserSystem.ErasureRegion.TOP, EraserSystem.ErasureRegion.BOTTOM:
			draw_line(Vector2(lo.x, c.y), Vector2(hi.x, c.y), line_color, 1.5)
		EraserSystem.ErasureRegion.RIGHT, EraserSystem.ErasureRegion.LEFT:
			draw_line(Vector2(c.x, lo.y), Vector2(c.x, hi.y), line_color, 1.5)
