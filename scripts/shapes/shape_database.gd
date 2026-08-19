class_name ShapeDatabase
extends RefCounted

static var templates: Dictionary = {}

static func _ensure_initialized() -> void:
	if not templates.is_empty():
		return
	templates["Triangle"] = ShapeTemplate.new("Triangle", "Triangle", 4, true)
	templates["Square"] = ShapeTemplate.new("Square", "Square", 5, true)
	templates["Circle"] = ShapeTemplate.new("Circle", "Circle", 7, true)
	templates["Pentagon"] = ShapeTemplate.new("Pentagon", "Pentagon", 6, true)
	templates["Star"] = ShapeTemplate.new("Star", "Star", 6, true)
	templates["Line"] = ShapeTemplate.new("Line", "Line", 2, false)
	templates["Polyline"] = ShapeTemplate.new("Polyline", "Polyline", 3, false)

static func identify_shape(p_node_ids: Array) -> ShapeTemplate:
	_ensure_initialized()
	var node_ids: Array[int] = []
	for n in p_node_ids:
		node_ids.append(int(n))
	if node_ids.size() < 2:
		return null
	var is_closed: bool = (node_ids.size() >= 4 and node_ids.front() == node_ids.back())
	var unique_nodes := {}
	for n in node_ids:
		unique_nodes[n] = true
	var u_count: int = unique_nodes.size()

	if is_closed:
		match u_count:
			3: return templates["Triangle"]
			4: return templates["Square"]
			5: return templates["Star"] if _is_star_pattern(node_ids) else templates["Pentagon"]
			_: return templates["Circle"] if u_count >= 7 else ShapeTemplate.new("Polygon", "Polygon", node_ids.size(), true)
	else:
		if u_count == 2:
			return templates["Line"]
		else:
			return templates["Polyline"]

static func _is_star_pattern(node_ids: Array[int]) -> bool:
	if node_ids.size() < 6:
		return false
	var step1: int = abs(node_ids[1] - node_ids[0])
	return step1 > 1 and step1 != 4

static func create_instance_from_path(p_node_ids: Array, board_def: BoardDefinition) -> ShapeInstance:
	var node_ids: Array[int] = []
	for n in p_node_ids:
		node_ids.append(int(n))
	var template := identify_shape(node_ids)
	if template == null:
		return null
	return template.create_instance(node_ids, board_def)

# The simple-shape vocabulary Easy-mode puzzles are built from. This is a generation
# difficulty lever, not a UI list — players swipe freely in both modes.
static func get_easy_mode_predefined_shapes(board_def: BoardDefinition) -> Array[Dictionary]:
	var N := board_def.node_count
	var shapes: Array[Dictionary] = []

	# 1. Triangle
	var tri_path := [0, int(N * 3 / 8), int(N * 5 / 8), 0]
	shapes.append({
		"name": "Triangle",
		"instance": create_instance_from_path(tri_path, board_def),
		"path": tri_path
	})

	# 2. Square
	var sq_path := [0, int(N / 4), int(N / 2), int(N * 3 / 4), 0]
	shapes.append({
		"name": "Square",
		"instance": create_instance_from_path(sq_path, board_def),
		"path": sq_path
	})

	# 3. Diamond
	var dia_path := [int(N / 8), int(N * 3 / 8), int(N * 5 / 8), int(N * 7 / 8), int(N / 8)]
	shapes.append({
		"name": "Diamond",
		"instance": create_instance_from_path(dia_path, board_def),
		"path": dia_path
	})

	# 4. Circle / Octagon
	var circ_path: Array[int] = []
	for i in range(N):
		circ_path.append(i)
	circ_path.append(0)
	shapes.append({
		"name": "Circle",
		"instance": create_instance_from_path(circ_path, board_def),
		"path": circ_path
	})

	# NOTE: no Star here. These shapes double as the Easy-mode candidate pool, so anything
	# listed can end up in a generated solution, and the star is too complex to read.

	# 5. Cross Line
	var line_path := [0, int(N / 2)]
	shapes.append({
		"name": "Line",
		"instance": create_instance_from_path(line_path, board_def),
		"path": line_path
	})

	return shapes
