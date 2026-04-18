extends RefCounted

class_name BackendContractRegistry

static var _contracts: Dictionary = {}


static func clear() -> void:
	_contracts.clear()


static func register(backend_class: String, contract: Dictionary) -> void:
	if backend_class.is_empty():
		return
	_contracts[backend_class] = contract.duplicate(true)


static func has_contract(backend_class: String) -> bool:
	return _contracts.has(backend_class)


static func get_contract(backend_class: String) -> Dictionary:
	var contract_value: Variant = _contracts.get(backend_class, {})
	if contract_value is Dictionary:
		var contract: Dictionary = contract_value
		return contract.duplicate(true)
	return {}


static func get_registered_backend_classes() -> Array[String]:
	var result: Array[String] = []
	for backend_class_value in _contracts.keys():
		result.append(str(backend_class_value))
	result.sort()
	return result


static func validate_payload(backend_class: String, payload: Dictionary, field_path: String = "") -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if backend_class.is_empty():
		issues.append(_build_issue(field_path, "backend_class", "backend_class must be a non-empty string."))
		return issues
	if not has_contract(backend_class):
		issues.append(_build_issue(field_path, "backend_class", "Unknown backend_class '%s'." % backend_class))
		return issues

	var contract := get_contract(backend_class)
	var required_fields := _read_string_array(contract.get("required", []))
	for required_field in required_fields:
		if payload.has(required_field):
			continue
		issues.append(_build_issue(field_path, required_field, "Missing required field '%s' for %s." % [required_field, backend_class]))

	var field_types_value: Variant = contract.get("field_types", {})
	if field_types_value is Dictionary:
		var field_types: Dictionary = field_types_value
		for field_name_value in field_types.keys():
			var field_name := str(field_name_value)
			if not payload.has(field_name):
				continue
			var expected_type := int(field_types.get(field_name_value, TYPE_NIL))
			var field_value: Variant = payload.get(field_name, null)
			if not _matches_variant_type(field_value, expected_type):
				issues.append(_build_issue(
					field_path,
					field_name,
					"Field '%s' for %s must be %s." % [field_name, backend_class, type_string(expected_type)]
				))

	var array_element_types_value: Variant = contract.get("array_element_types", {})
	if array_element_types_value is Dictionary:
		var array_element_types: Dictionary = array_element_types_value
		for field_name_value in array_element_types.keys():
			var field_name := str(field_name_value)
			if not payload.has(field_name):
				continue
			var field_value: Variant = payload.get(field_name, [])
			if not field_value is Array:
				continue
			var expected_element_type := int(array_element_types.get(field_name_value, TYPE_NIL))
			var values: Array = field_value
			for index in range(values.size()):
				var element_value: Variant = values[index]
				if _matches_variant_type(element_value, expected_element_type):
					continue
				issues.append(_build_issue(
					field_path,
					"%s[%d]" % [field_name, index],
					"Field '%s' for %s must contain only %s values." % [field_name, backend_class, type_string(expected_element_type)]
				))

	return issues


static func _read_string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		return result
	var entries: Array = values
	for entry in entries:
		var text := str(entry)
		if text.is_empty():
			continue
		result.append(text)
	return result


static func _matches_variant_type(value: Variant, expected_type: int) -> bool:
	if expected_type == TYPE_NIL:
		return true
	match expected_type:
		TYPE_INT:
			return value is int
		TYPE_FLOAT:
			return value is float or value is int
		TYPE_STRING:
			return value is String
		TYPE_BOOL:
			return value is bool
		TYPE_ARRAY:
			return value is Array
		TYPE_DICTIONARY:
			return value is Dictionary
		_:
			return typeof(value) == expected_type


static func _build_issue(field_path: String, field_name: String, message: String) -> Dictionary:
	var normalized_field_path := field_name if field_path.is_empty() else "%s.%s" % [field_path, field_name]
	return {
		"field_path": normalized_field_path,
		"message": message,
	}
