extends PanelContainer

class_name StatDeltaSheet

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _stats_label: RichTextLabel = $MarginContainer/VBoxContainer/StatsLabel


func render(view_model: Dictionary) -> void:
	_title_label.text = str(view_model.get("title", "Projected Stats"))
	var current_stats_data: Variant = view_model.get("current_stats", {})
	var projected_stats_data: Variant = view_model.get("projected_stats", {})
	var current_stats: Dictionary = {}
	var projected_stats: Dictionary = {}
	if current_stats_data is Dictionary:
		current_stats = current_stats_data
	if projected_stats_data is Dictionary:
		projected_stats = projected_stats_data
	_stats_label.text = "\n".join(_build_lines(current_stats, projected_stats))


func _build_lines(current_stats: Dictionary, projected_stats: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	var stat_keys: Array = projected_stats.keys()
	for key in current_stats.keys():
		if not key in stat_keys:
			stat_keys.append(key)
	stat_keys.sort()
	for key in stat_keys:
		var stat_id := str(key)
		var current_value := float(current_stats.get(stat_id, 0.0))
		var projected_value := float(projected_stats.get(stat_id, 0.0))
		var delta := projected_value - current_value
		var delta_text := ""
		if absf(delta) > 0.001:
			delta_text = " (%+.0f)" % delta
		result.append("%s: %.0f -> %.0f%s" % [stat_id, current_value, projected_value, delta_text])
	if result.is_empty():
		result.append("No stats available.")
	return result
