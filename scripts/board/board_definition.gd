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

func _init(
	p_node_count: int = 8,
	p_res: Vector2 = Vector2(64, 64),
	p_erasure_start_phase: int = 0,
	p_erasure_shape: int = EraserSystem.ErasureShape.DIAGONAL_WEDGE
):
	self.node_count = p_node_count
	self.resolution = p_res
	self.center = p_res / 2.0
	self.radius = min(p_res.x, p_res.y) * 0.38
	self.erasure_start_phase = posmod(p_erasure_start_phase, 4)
	self.erasure_shape = p_erasure_shape
	_compute_node_positions()

func duplicate_board() -> BoardDefinition:
	return BoardDefinition.new(node_count, resolution, erasure_start_phase, erasure_shape)

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
