class_name BoardDefinition
extends RefCounted

var node_count: int = 8
var resolution: Vector2 = Vector2(64, 64)
var center: Vector2 = Vector2(32, 32)
var radius: float = 24.0
var node_positions: Array[Vector2] = []

# Rotates the TOP -> RIGHT -> BOTTOM -> LEFT erasure cycle. Turn 0 erases
# (0 + erasure_start_phase) % 4 instead of always TOP, which lets puzzles with the
# same turn count still finish on different zones.
var erasure_start_phase: int = 0

# Which shape each erasure takes out of the field: a 90-degree wedge cut by the X
# (default), or the legacy half of the board.
var erasure_shape: int = EraserSystem.ErasureShape.DIAGONAL_WEDGE

# Which of EraserSystem.ERASURE_CYCLES this board walks. Purely a spatial ordering --
# every cycle still takes one quarter per turn and still closes after four, so the turn
# structure of a puzzle is identical under all of them.
var erasure_cycle_id: int = EraserSystem.CYCLE_CLOCKWISE

# An explicit zone per turn, overriding the cycle. Empty means "follow the cycle", which
# is how every generated puzzle is built. It is filled in only when something outside the
# rules decides the schedule -- in ERASE mode that something is the player. Keeping it on
# the board means the simulator, the timeline and the board rendering all read the
# player's choices through the same call they already use.
var erasure_override: Array[int] = []

func _init(
	p_node_count: int = 8,
	p_res: Vector2 = Vector2(64, 64),
	p_erasure_start_phase: int = 0,
	p_erasure_shape: int = EraserSystem.ErasureShape.DIAGONAL_WEDGE,
	p_erasure_cycle_id: int = EraserSystem.CYCLE_CLOCKWISE
):
	self.node_count = p_node_count
	self.resolution = p_res
	self.center = p_res / 2.0
	self.radius = min(p_res.x, p_res.y) * 0.38
	self.erasure_start_phase = posmod(p_erasure_start_phase, 4)
	self.erasure_shape = p_erasure_shape
	self.erasure_cycle_id = posmod(p_erasure_cycle_id, EraserSystem.CYCLE_COUNT)
	_compute_node_positions()

func duplicate_board() -> BoardDefinition:
	var copy := BoardDefinition.new(node_count, resolution, erasure_start_phase, erasure_shape,
		erasure_cycle_id)
	copy.erasure_override = erasure_override.duplicate()
	return copy

# A board that erases exactly these zones, in this order.
func with_erasure_override(zones: Array[int]) -> BoardDefinition:
	var copy := duplicate_board()
	copy.erasure_override = zones.duplicate()
	return copy

func _compute_node_positions() -> void:
	node_positions.clear()
	for i in range(node_count):
		# Node 0 is at Top (-90 degrees)
		var angle := -PI / 2.0 + (i * TAU / float(node_count))
		var raw_pos := center + Vector2(cos(angle), sin(angle)) * radius
		# Quantize to grid
		var q_pos := Vector2(round(raw_pos.x), round(raw_pos.y))
		node_positions.append(q_pos)

func get_node_position(node_id: int) -> Vector2:
	if node_id >= 0 and node_id < node_positions.size():
		return node_positions[node_id]
	return center
