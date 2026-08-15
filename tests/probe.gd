extends SceneTree

# MEDIUM = PATTERN, then from its final Draw a second PATTERN starts, sharing that Draw.
# Only patterns ending in Draw can be continued, so:
#   [D,S,D] or [D,D,D]  +  any PATTERN, overlapping on the shared Draw  = 5 turns
#   optional leading Skip                                               = 6 turns
func _init():
	var bd := BoardDefinition.new(8)
	var patterns := [[1, 0, 1], [1, 1, 0], [1, 1, 1]]

	var chains: Array = []
	for prefix in [[], [0]]:
		for first in patterns:
			if first[first.size() - 1] != 1:
				continue # cannot continue from a Skip
			for second in patterns:
				var seq: Array = []
				seq.append_array(prefix)
				seq.append_array(first)
				seq.append_array(second.slice(1)) # share the first Draw
				chains.append(seq)

	print("chain count: ", chains.size())

	for n in [5, 6]:
		print("max_turns=%d survivable=%s" % [n, str(PuzzleSimulator.get_survivable_turns(bd, n))])

	var pool := PuzzleGenerator.generate_candidate_pool(bd, PuzzleGenerator.Difficulty.NORMAL)

	for n in [5, 6]:
		for t in range(n):
			var reaches := 0
			var alive_at_boundary := 0
			for s in pool:
				var sol := PuzzleSolution.new(n)
				sol.set_action(t, s)
				if not PuzzleSimulator.simulate(sol, bd).is_empty():
					reaches += 1
				# boundary = last turn of the first pattern
				var boundary: int = n - 3
				if t <= boundary and not PuzzleSimulator.simulate_up_to_turn(sol, bd, boundary).is_empty():
					alive_at_boundary += 1
			print("  n=%d turn %d -> reaches final target %d/%d, alive at boundary %d/%d" % [
				n, t, reaches, pool.size(), alive_at_boundary, pool.size()])

	print("--- the chains ---")
	for c in chains:
		var s := ""
		for a in c:
			s += "D" if a == 1 else "S"
		var draws: Array[int] = []
		for i in range(c.size()):
			if c[i] == 1:
				draws.append(i)
		var dead: Array[int] = []
		var survivable := PuzzleSimulator.get_survivable_turns(bd, c.size())
		for d in draws:
			if not survivable.has(d):
				dead.append(d)
		print("  %-7s turns=%d draws=%s dead_draws=%s" % [s, c.size(), str(draws), str(dead)])

	quit(0)
