@tool
extends SceneTree

func _init() -> void:
	print("--- SCRIPT RUNNING ---")
	# We can't access DataManager directly if it's an autoload, let's just parse the json
	var file = FileAccess.open("res://mods/base/data/locations.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		print("JSON parsed: ", json != null)
		if json and json.has("locations"):
			print("Locations count: ", json["locations"].size())
	print("--- SCRIPT DONE ---")
	quit()
