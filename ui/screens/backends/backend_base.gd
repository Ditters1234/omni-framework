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
