extends Resource

class_name FixtureDialogueResource

class FixtureDialogueLine:
	extends RefCounted

	var id: String = ""
	var character: String = ""
	var text: String = ""
	var next_id: String = ""
	var responses: Array[RefCounted] = []


class FixtureDialogueResponse:
	extends RefCounted

	var text: String = ""
	var next_id: String = ""
	var is_allowed: bool = true


func get_next_dialogue_line(
		title: String = "",
		extra_game_states: Array = [],
		_mutation_behaviour: Variant = null) -> RefCounted:
	if title == "ai_handoff":
		_request_ai_handoff(extra_game_states)
		return null

	var talk_freely := FixtureDialogueResponse.new()
	talk_freely.text = "Talk freely."
	talk_freely.next_id = "ai_handoff"

	var leave := FixtureDialogueResponse.new()
	leave.text = "Maybe later."
	leave.next_id = ""

	var line := FixtureDialogueLine.new()
	line.id = "start"
	line.character = "Fixture Vendor"
	line.text = "Need something?"
	line.responses = [leave]
	if AIManager.is_available():
		line.responses.push_front(talk_freely)
	return line


func _request_ai_handoff(extra_game_states: Array) -> void:
	for state_value in extra_game_states:
		var state_object := state_value as Object
		if state_object != null and state_object.has_method("ai_chat_open"):
			state_object.call("ai_chat_open")
			return
