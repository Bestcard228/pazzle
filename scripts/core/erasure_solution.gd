class_name ErasureSolution
extends RefCounted

# What the player commits in ERASE mode: one zone per turn, in the order they picked them.
#
# This is deliberately not a PuzzleSolution. A PuzzleSolution answers "what was drawn on
# each turn", and in ERASE mode that half is given -- it is the puzzle. The open half is
# the schedule, so that is what this records.
#
# The one rule is EraserSystem.legal_zones_after: a zone cannot come round again until the
# other three have been used. Under four turns or fewer that is simply "no zone twice",
# which is the limit the mode is built around; over longer puzzles it is what keeps any
# four consecutive erasures clearing the whole field.

var max_turns: int
var zones: Array[int] = []

func _init(p_max_turns: int = 4):
	self.max_turns = p_max_turns

func is_full() -> bool:
	return zones.size() >= max_turns

func get_turn_count() -> int:
	return zones.size()

func can_add(zone: int) -> bool:
	if is_full():
		return false
	return EraserSystem.is_legal_next_zone(zones, zone)

func add_zone(zone: int) -> bool:
	if not can_add(zone):
		return false
	zones.append(posmod(zone, EraserSystem.PHASE_COUNT))
	return true

# Backing out the last pick, so a misread is not a dead puzzle.
func undo_last() -> int:
	if zones.is_empty():
		return -1
	return zones.pop_back()

func get_zone(turn: int) -> int:
	if turn < 0 or turn >= zones.size():
		return -1
	return zones[turn]

func legal_zones() -> Array[int]:
	if is_full():
		return []
	return EraserSystem.legal_zones_after(zones)

func clear() -> void:
	zones.clear()

func duplicate_solution() -> ErasureSolution:
	var copy := ErasureSolution.new(max_turns)
	copy.zones = zones.duplicate()
	return copy

# The board this schedule describes: the same field, erased the way the player chose.
func apply_to(board_def: BoardDefinition) -> BoardDefinition:
	return board_def.with_erasure_override(zones)

func matches(other_zones: Array[int]) -> bool:
	return zones == other_zones

func _to_string() -> String:
	var names: Array[String] = []
	for zone in zones:
		names.append(EraserSystem.get_region_name(zone))
	return "ErasureSolution[%s]" % " > ".join(names)
