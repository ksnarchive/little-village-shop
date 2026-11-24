class_name CharacterAppearance
extends RefCounted
## Stable numeric IDs are part of the save format. Options are available to everyone.
const SKIN := ["#F5D3BD", "#E8BA96", "#D2A180", "#BA8464", "#95664F", "#704D40"]
const HAIR := ["#584A40", "#80604B", "#AA7853", "#C4A06C", "#D4C5A4", "#A35F48", "#8B8790", "#D4D0BD"]
const EYES := ["#74513D", "#53665A", "#607E86", "#899084", "#AD8852", "#554A44"]
const HAIRSTYLES := ["Короткая", "Каре", "Кудри", "Длинные", "Косички", "Пучок", "Хвост", "Чёлка набок"]
const OUTFITS := ["Фартук", "Кардиган", "Комбинезон", "Полосатый свитер", "Сарафан", "Рубашка с платком"]
const LIMITS := {"skin": 6, "hairstyle": 8, "hair_color": 8, "eyes": 6, "outfit": 6}
const DEFAULT := {"name": "Саша", "skin": 0, "hairstyle": 0, "hair_color": 1, "eyes": 0, "outfit": 0}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or not value.get("name") is String:
		return false
	if clean_name(value.name) != value.name or value.name.is_empty():
		return false
	for key in LIMITS:
		var index: Variant = value.get(key)
		if not (index is int or index is float) or not is_finite(float(index)):
			return false
		if index != floor(float(index)) or index < 0 or index >= LIMITS[key]:
			return false
	return true

static func clean_name(value: String) -> String:
	var result := ""
	for character in value.strip_edges():
		if character.unicode_at(0) >= 32 and character.unicode_at(0) != 127:
			result += character
	return result.left(24).strip_edges()

static func randomized(rng: RandomNumberGenerator, character_name: String) -> Dictionary:
	var result := {"name": character_name}
	for key in LIMITS:
		result[key] = rng.randi_range(0, LIMITS[key] - 1)
	return result
