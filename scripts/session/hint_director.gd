class_name HintDirector
extends RefCounted

# When to offer a hint, and what the hint is.
#
# It decides; the UI shows. That split matters because "what the hint is" is a question
# about the puzzle -- which shape, which quarter, which colour -- while lighting a lamp
# and popping a button are questions about the screen.
#
# The honesty rule runs through all of it: a hint reads off the intended solution, so it
# can only be given while the player is still on that line. Once they have diverged, the
# truthful hint is to start over, and this says so rather than pointing at a move that no
# longer leads anywhere.

signal offered()

const IDLE_SECONDS := 20.0

# What the UI should do with a request.
enum Kind {
	DRAW_PATH,     # trace this path, in `layer`
	SKIP_TURN,     # this turn draws nothing
	ERASE_ZONE,    # take this quarter next
	SCHEDULE_DONE, # nothing left to schedule
	OFF_PLAN,      # the player has left the line the hint could speak for
}

var session: PuzzleSession
var idle_time: float = 0.0
var is_offered: bool = false
var pulse_time: float = 0.0

func _init(p_session: PuzzleSession = null):
	session = p_session

# Returns true on the tick where the hint becomes available, so the UI raises the lamp
# once rather than every frame after.
func tick(delta: float) -> bool:
	if is_offered:
		pulse_time += delta
		return false

	idle_time += delta
	if idle_time < IDLE_SECONDS:
		return false

	is_offered = true
	pulse_time = 0.0
	offered.emit()
	return true

# The lamp breathes while it waits to be noticed.
func pulse() -> float:
	return 0.75 + 0.25 * sin(pulse_time * 3.0)

# Any resolved turn earns a fresh idle window: the player is making progress again.
func withdraw() -> void:
	idle_time = 0.0
	is_offered = false
	pulse_time = 0.0

# What to show for the turn in hand.
func request() -> Dictionary:
	idle_time = 0.0

	if session.uses_erase_input():
		return _erase_request()

	if not follows_reference():
		return {"kind": Kind.OFF_PLAN}

	# A layered hint points at the shape for the colour being painted right now, not at
	# layer 0 standing in for all of them.
	var shape: ShapeInstance = null
	if session.uses_layers():
		shape = session.puzzle.layered_solution.get_shape(session.turn, session.active_layer)
	else:
		var action := session.puzzle.reference_solution.get_action(session.turn)
		shape = action.shape_instance if action != null else null

	if shape == null:
		return {"kind": Kind.SKIP_TURN}

	return {
		"kind": Kind.DRAW_PATH,
		"path": shape.node_ids,
		"layer": session.active_layer,
	}

# In ERASE mode the hint is the next quarter the generated schedule takes. A different
# schedule may still reach the target, so once the player has diverged this can no longer
# be pointed at honestly.
func _erase_request() -> Dictionary:
	if not session.erase.follows_reference():
		return {"kind": Kind.OFF_PLAN}

	var zone := session.erase.reference_zone_for_current_turn()
	if zone < 0:
		return {"kind": Kind.SCHEDULE_DONE}

	return {"kind": Kind.ERASE_ZONE, "zone": zone}

# True while every turn the player has resolved matches the intended solution, which is
# what makes the next intended action a usable hint.
func follows_reference() -> bool:
	if session.uses_layers():
		return _layered_follows_reference()

	var reference := session.puzzle.reference_solution
	if reference == null:
		return false

	for t in range(session.turn):
		if not _same_shape(session.solution.get_action(t), reference.get_action(t)):
			return false

	return true

# The same question colour for colour, including the turn in progress: a hint for green
# is only honest if red has already gone down where the plan says it should.
func _layered_follows_reference() -> bool:
	var plan: LayeredSolution = session.puzzle.layered_solution
	if plan == null:
		return false

	for t in range(session.turn + 1):
		for layer in range(session.layer_count()):
			if t == session.turn and layer >= session.active_layer:
				break
			if not _same_geometry(session.layered.get_shape(t, layer), plan.get_shape(t, layer)):
				return false

	return true

func _same_shape(mine: DrawAction, theirs: DrawAction) -> bool:
	return _same_geometry(
		mine.shape_instance if mine != null else null,
		theirs.shape_instance if theirs != null else null)

func _same_geometry(mine: ShapeInstance, theirs: ShapeInstance) -> bool:
	if (mine == null) != (theirs == null):
		return false
	if mine == null:
		return true
	return mine.geometry.is_equivalent_to(theirs.geometry)
