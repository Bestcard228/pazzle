class_name EraseArea
extends RefCounted

# A convex area of the board that an erasure wipes.
#
# RECT  - the original half-plane eraser: a rectangle covering half the grid.
# WEDGE - the default eraser: the circular field is cut by two diagonals crossing at the
#         centre (an X), leaving four 90-degree wedges. A wedge is a quarter of the
#         field rather than a half, so geometry can outlive three erasures instead of
#         two, which is what makes long puzzles have more than two live turns.
#
# Both kinds answer the same two questions, so the clipper needs only one algorithm.

enum Kind { RECT, WEDGE }

const COS_45 := 0.7071067811865476

# Boundary points are treated as inside so that a segment lying exactly along a diagonal
# is erased by the wedges that share it. Without this it would belong to no wedge at all
# and survive forever.
const BOUNDARY_BIAS := 0.000001

var kind: int = Kind.RECT
var rect: Rect2 = Rect2()
var apex: Vector2 = Vector2.ZERO
var axis: Vector2 = Vector2.ZERO
var half_angle_cos: float = COS_45

static func make_rect(p_rect: Rect2) -> EraseArea:
	var region := EraseArea.new()
	region.kind = Kind.RECT
	region.rect = p_rect
	return region

static func make_wedge(p_apex: Vector2, p_axis: Vector2, p_half_angle_cos: float = COS_45) -> EraseArea:
	var region := EraseArea.new()
	region.kind = Kind.WEDGE
	region.apex = p_apex
	region.axis = p_axis.normalized()
	region.half_angle_cos = p_half_angle_cos
	return region

func is_empty() -> bool:
	if kind == Kind.WEDGE:
		return axis == Vector2.ZERO
	return rect.size.x <= 0.0 or rect.size.y <= 0.0

func contains(point: Vector2, tol: float = 0.001) -> bool:
	match kind:
		Kind.RECT:
			return (point.x > rect.position.x + tol and point.x < rect.position.x + rect.size.x - tol
				and point.y > rect.position.y + tol and point.y < rect.position.y + rect.size.y - tol)
		Kind.WEDGE:
			var v := point - apex
			var dist := v.length()
			if dist <= tol:
				return true # the crossing point of the X belongs to every wedge
			return (v.dot(axis) / dist) >= half_angle_cos - BOUNDARY_BIAS
	return false

# Parameters in (0, 1) where the segment p1->p2 crosses this region's boundary. The
# clipper splits the segment at these points and then keeps the pieces that fall outside.
func get_split_parameters(p1: Vector2, p2: Vector2, tol: float = 0.001) -> Array[float]:
	var out: Array[float] = []
	var dir := p2 - p1

	match kind:
		Kind.RECT:
			if absf(dir.x) > tol:
				_append_parameter(out, (rect.position.x - p1.x) / dir.x, tol)
				_append_parameter(out, (rect.position.x + rect.size.x - p1.x) / dir.x, tol)
			if absf(dir.y) > tol:
				_append_parameter(out, (rect.position.y - p1.y) / dir.y, tol)
				_append_parameter(out, (rect.position.y + rect.size.y - p1.y) / dir.y, tol)

		Kind.WEDGE:
			for boundary_dir in get_boundary_directions():
				var denom := dir.cross(boundary_dir)
				if absf(denom) > BOUNDARY_BIAS:
					_append_parameter(out, (apex - p1).cross(boundary_dir) / denom, tol)

	return out

# The two arms of the X that bound this wedge.
func get_boundary_directions() -> Array[Vector2]:
	if kind != Kind.WEDGE:
		return []
	var half := acos(clampf(half_angle_cos, -1.0, 1.0))
	return [axis.rotated(half), axis.rotated(-half)]

func _append_parameter(out: Array[float], t: float, tol: float) -> void:
	if t > tol and t < 1.0 - tol:
		out.append(t)
