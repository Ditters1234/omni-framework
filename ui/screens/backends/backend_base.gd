extends RefCounted

class_name OmniBackendBase


func initialize(_params: Dictionary) -> void:
	pass


func build_view_model() -> Dictionary:
	return {}


func confirm() -> Dictionary:
	return {"status": "ok"}


func get_required_params() -> Array[String]:
	return []


func _get_string_param(params: Dictionary, field_name: String, default_value: String = "") -> String:
	return str(params.get(field_name, default_value))


func _get_bool_param(params: Dictionary, field_name: String, default_value: bool) -> bool:
	var value: Variant = params.get(field_name, default_value)
	if value is bool:
		return bool(value)
	return default_value


func _get_int_param(params: Dictionary, field_name: String, default_value: int, minimum_value: int = -2147483648) -> int:
	var value: Variant = params.get(field_name, default_value)
	if value is int:
		return maxi(int(value), minimum_value)
	return maxi(default_value, minimum_value)


func _get_float_param(params: Dictionary, field_name: String, default_value: float, minimum_value: float = -INF) -> float:
	var value: Variant = params.get(field_name, default_value)
	if value is int or value is float:
		return maxf(float(value), minimum_value)
	return maxf(default_value, minimum_value)
