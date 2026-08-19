class_name TestGeometry
extends RefCounted

static func run_all_tests() -> Array[int]:
	print("--- Running TestGeometry ---")

	var results := {
		"test_canonicalization": test_canonicalization(),
		"test_line_clipping": test_line_clipping(),
	}

	var passed := 0
	for name in results.keys():
		if results[name]:
			passed += 1
			print("  [PASS] %s" % name)
		else:
			print("  [FAIL] %s" % name)

	return [passed, results.size()]

static func test_canonicalization() -> bool:
	var g1 := VectorGeometry.new()
	g1.add_line(Vector2(10, 20), Vector2(30, 40))
	g1.add_line(Vector2(5, 5), Vector2(15, 15))

	var g2 := VectorGeometry.new()
	# Reverse line directions and order
	g2.add_line(Vector2(15, 15), Vector2(5, 5))
	g2.add_line(Vector2(30, 40), Vector2(10, 20))

	return g1.is_equivalent_to(g2)

static func test_line_clipping() -> bool:
	# Vertical line (16, 10) to (16, 50) clipped against Top erased rect [0, 0, 64, 32]
	var seg := VectorGeometry.LineSegment2D.new(Vector2(16, 10), Vector2(16, 50))
	var erased_rect := Rect2(0, 0, 64, 32)

	var clipped := GeometryClipper.clip_segment_out_rect(seg, erased_rect)
	if clipped.size() != 1:
		return false

	var remaining := clipped[0]
	# Remaining line should be (16, 32) to (16, 50)
	var expected_p1 := Vector2(16, 32)
	var expected_p2 := Vector2(16, 50)

	var norm_rem := remaining.get_normalized()
	return norm_rem.p1.distance_to(expected_p1) < 0.01 and norm_rem.p2.distance_to(expected_p2) < 0.01
