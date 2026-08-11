class_name DrawAction
extends RefCounted

var turn: int
var shape_instance: ShapeInstance

func _init(p_turn: int = 0, p_shape_instance: ShapeInstance = null):
	self.turn = p_turn
	self.shape_instance = p_shape_instance

func duplicate_action() -> DrawAction:
	var inst_copy: ShapeInstance = shape_instance.duplicate_instance() if shape_instance != null else null
	return DrawAction.new(turn, inst_copy)

func _to_string() -> String:
	if shape_instance == null:
		return "Turn %d: Nothing" % turn
	return "Turn %d: %s" % [turn, str(shape_instance)]
