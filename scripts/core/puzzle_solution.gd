class_name PuzzleSolution
extends RefCounted

var max_turns: int
var actions: Array[DrawAction] = []

func _init(p_max_turns: int = 4):
	self.max_turns = p_max_turns
	for t in range(p_max_turns):
		actions.append(DrawAction.new(t, null))

func set_action(turn: int, shape_instance: ShapeInstance) -> void:
	if turn >= 0 and turn < max_turns:
		actions[turn] = DrawAction.new(turn, shape_instance)

func clear_action(turn: int) -> void:
	set_action(turn, null)

func get_action(turn: int) -> DrawAction:
	if turn >= 0 and turn < max_turns:
		return actions[turn]
	return null

func get_turn_count() -> int:
	return max_turns

func duplicate_solution() -> PuzzleSolution:
	var copy := PuzzleSolution.new(max_turns)
	for t in range(max_turns):
		copy.actions[t] = actions[t].duplicate_action()
	return copy

func get_non_empty_action_count() -> int:
	var count := 0
	for act in actions:
		if act.shape_instance != null:
			count += 1
	return count

func _to_string() -> String:
	var str_list: Array[String] = []
	for act in actions:
		str_list.append(str(act))
	return "Solution[\n  " + ",\n  ".join(str_list) + "\n]"
