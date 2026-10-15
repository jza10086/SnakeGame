class_name SnakeSaveStore
extends RefCounted
## ConfigFile keeps the highest score and sound preference in Godot's user folder.
var path: String = "user://snake_save.cfg"
var best: int = 0
var muted: bool = false

func load_data() -> void:
	var data := ConfigFile.new()
	if data.load(path) != OK:
		return
	var saved_best: Variant = data.get_value("player", "best", 0)
	if saved_best is int or saved_best is float:
		best = clampi(int(saved_best), 0, 1000000)
	var saved_muted: Variant = data.get_value("audio", "muted", false)
	if saved_muted is bool:
		muted = saved_muted

func save_data() -> Error:
	var data := ConfigFile.new()
	data.set_value("player", "best", best)
	data.set_value("audio", "muted", muted)
	return data.save(path)

func record_score(value: int) -> bool:
	if value <= best:
		return false
	best = value
	save_data()
	return true
