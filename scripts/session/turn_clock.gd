class_name TurnClock
extends RefCounted

# The per-turn countdown.
#
# It knows how long a turn is and how much of it is left, and nothing else -- what running
# out *means* is the session's business, not the clock's. (It means a skip: a turn nobody
# acted on, which is a move the rules already have.)
#
# The running flag is not decoration. Without it "not started yet" and "expired" are the
# same state -- both are zero seconds left -- and any path that forgets to start the clock
# silently eats a turn on the next frame.

var limit: float = 0.0
var remaining: float = 0.0
var running: bool = false

func set_limit(seconds: float) -> void:
	limit = maxf(0.0, seconds)

func has_limit() -> bool:
	return limit > 0.0

func start() -> void:
	remaining = limit
	running = has_limit()

func stop() -> void:
	running = false
	remaining = 0.0

# Advances the clock. Returns true on the single tick where the turn runs out, so the
# caller resolves the expiry once rather than every frame after it.
func tick(delta: float) -> bool:
	if not running:
		return false

	remaining = maxf(0.0, remaining - delta)
	if remaining > 0.0:
		return false

	running = false
	return true

# How much of the turn is left, 1 down to 0, or -1 when there is no clock to show.
func fraction() -> float:
	if not running or not has_limit():
		return -1.0
	return remaining / limit
