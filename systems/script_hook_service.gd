## ScriptHookService -- Shared runtime helper for invoking template hooks.
## Systems call this with template dictionaries so hook lookup stays centralized.
extends RefCounted

class_name ScriptHookService


static func invoke_template_hook(template: Dictionary, method_name: String, args: Array = []) -> void:
	if template.is_empty() or method_name.is_empty():
		return
	var script_path := _extract_script_path(template)
	if script_path.is_empty():
		return
	var hook := ModLoader.get_script_hook(script_path)
	if hook == null or not hook.has_method(method_name):
		return
	hook.callv(method_name, args)


static func _extract_script_path(template: Dictionary) -> String:
	return str(template.get("script_path", template.get("script_hook", "")))
