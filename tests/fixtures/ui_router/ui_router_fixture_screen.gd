extends Control

var initialize_calls: Array[Dictionary] = []
var hidden_count: int = 0
var revealed_count: int = 0


func initialize(params: Dictionary = {}) -> void:
	initialize_calls.append(params.duplicate(true))


func on_route_hidden() -> void:
	hidden_count += 1


func on_route_revealed() -> void:
	revealed_count += 1
