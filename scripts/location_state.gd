class_name LocationState
extends RefCounted
## Explicit migration boundary: old completed games stay in their shop.
const STATION_SPAWN := Vector2(350, 230)
const STATION_BOUNDS := Rect2(0, 0, 720, 480)
const LOCATIONS := {
	"station": {"scene": "res://scenes/locations/station.tscn", "spawn": STATION_SPAWN, "bounds": Rect2(8, 160, 704, 312)},
	"shop": {"scene": "res://scenes/main.tscn", "spawn": Vector2(320, 222), "bounds": Rect2(0, 0, 640, 360)}
}

static func fresh(location: String = "shop") -> Dictionary:
	var point: Vector2 = LOCATIONS.get(location, LOCATIONS.station).spawn
	return {"location": location, "position": [point.x, point.y], "arrival_time": 0.0, "thought": 0}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or (value.get("location") != "train" and not LOCATIONS.has(value.get("location"))):
		return false
	var point: Variant = value.get("position")
	if not point is Array or point.size() != 2:
		return false
	for coordinate in point:
		if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)):
			return false
	var bounds: Rect2 = LOCATIONS.get(value.location, LOCATIONS.station).bounds
	if not bounds.has_point(Vector2(point[0], point[1])):
		return false
	var time: Variant = value.get("arrival_time")
	var thought: Variant = value.get("thought")
	return (time is int or time is float) and is_finite(float(time)) and time >= 0 and time <= 10 \
		and (thought is int or thought is float) and thought >= 0 and thought <= 3 and thought == floor(float(thought))
