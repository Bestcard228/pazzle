class_name ShapeTemplate
extends RefCounted

var id: String
var name: String
var min_nodes: int
var is_closed: bool

func _init(p_id: String = "", p_name: String = "", p_min_nodes: int = 3, p_closed: bool = true):
	self.id = p_id
	self.name = p_name
	self.min_nodes = p_min_nodes
	self.is_closed = p_closed


func create_instance(node_ids: Array[int], board_def: BoardDefinition) -> ShapeInstance:
	var geom := VectorGeometry.new()
	for i in range(node_ids.size() - 1):
		var p_a := board_def.get_node_position(node_ids[i])
		var p_b := board_def.get_node_position(node_ids[i + 1])
		geom.add_line(p_a, p_b)

	var inst := ShapeInstance.new()
	inst.template_id = id
	inst.node_ids = node_ids.duplicate()
	inst.geometry = geom
	return inst
