class_name ShapeInstance
extends RefCounted

var template_id: String
var node_ids: Array[int] = []
var geometry: VectorGeometry

func _init(p_template_id: String = "", p_node_ids: Array[int] = [], p_geometry: VectorGeometry = null):
	self.template_id = p_template_id
	self.node_ids = p_node_ids.duplicate()
	self.geometry = p_geometry if p_geometry != null else VectorGeometry.new()

func duplicate_instance() -> ShapeInstance:
	var copy := ShapeInstance.new()
	copy.template_id = template_id
	copy.node_ids = node_ids.duplicate()
	copy.geometry = geometry.duplicate_geometry()
	return copy

func _to_string() -> String:
	return "ShapeInstance(%s, nodes=%s)" % [template_id, str(node_ids)]
