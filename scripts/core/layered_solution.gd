class_name LayeredSolution
extends RefCounted

# One PuzzleSolution per colour layer, sharing a turn clock.
#
# This is deliberately not a turn x layer matrix. Each layer is erased once per turn by
# its own walk, which makes it a well-formed single-layer puzzle in its own right -- so
# holding it as an actual PuzzleSolution means every existing validator and the simulator
# apply to it unchanged, and a one-layer LayeredSolution is exactly the original game.

var layer_count: int
var max_turns: int
var layers: Array[PuzzleSolution] = []

func _init(p_layer_count: int = 2, p_max_turns: int = 4):
	self.layer_count = LayerSystem.clamp_layer_count(p_layer_count)
	self.max_turns = p_max_turns
	for i in range(self.layer_count):
		layers.append(PuzzleSolution.new(p_max_turns))

func get_layer(layer: int) -> PuzzleSolution:
	if layer < 0 or layer >= layers.size():
		return null
	return layers[layer]

func set_action(turn: int, layer: int, shape_instance: ShapeInstance) -> void:
	var solution := get_layer(layer)
	if solution != null:
		solution.set_action(turn, shape_instance)

func clear_action(turn: int, layer: int) -> void:
	set_action(turn, layer, null)

func get_action(turn: int, layer: int) -> DrawAction:
	var solution := get_layer(layer)
	return solution.get_action(turn) if solution != null else null

func get_shape(turn: int, layer: int) -> ShapeInstance:
	var action := get_action(turn, layer)
	return action.shape_instance if action != null else null

# Whether any layer draws on this turn. The sequences move all layers together, so this is
# also "is this turn a D".
func is_draw_turn(turn: int) -> bool:
	for layer in range(layers.size()):
		if get_shape(turn, layer) != null:
			return true
	return false

func get_non_empty_action_count() -> int:
	var count := 0
	for solution in layers:
		count += solution.get_non_empty_action_count()
	return count

func duplicate_solution() -> LayeredSolution:
	var copy := LayeredSolution.new(layer_count, max_turns)
	for i in range(layers.size()):
		copy.layers[i] = layers[i].duplicate_solution()
	return copy

func _to_string() -> String:
	var parts: Array[String] = []
	for i in range(layers.size()):
		parts.append("%s: %s" % [LayerSystem.get_layer_name(i), str(layers[i])])
	return "LayeredSolution[\n  " + ",\n  ".join(parts) + "\n]"
