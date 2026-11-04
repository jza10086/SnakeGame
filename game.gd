extends "res://games/protocols/godot_party_default_protocol/ranked_round.gd"
## Independent responsive boards. The host bounds monotonic progress and owns the deadline.
const Model: Script = preload("res://games/minigame/godot_party_default_snake_game/snake_model.gd")
const BoardView: Script = preload("res://games/minigame/godot_party_default_snake_game/board_view.gd")
const Sounds: Script = preload("res://games/minigame/godot_party_default_snake_game/sound_bank.gd")
var sounds: Node
@onready var board: BoardView = %Board
@onready var model: Model = board.model
var timer: float = 0.0
var reporting: float = 0.0
var steps: int = 0
var reported_done: bool = false
var records: Dictionary = {}
var speed: float = 1.0

func build_game() -> void:
	sounds = Sounds.new()
	add_child(sounds)

## Let the selected protocol apply the shared 3D graphics preferences.
func godot_party_graphics_targets() -> Dictionary:
	return {"world": board.world, "sun": board.sun, "materials_root": board}

func start_game() -> void:
	speed = {"舒缓": 0.8, "标准": 1.0, "高速": 1.25}.get(settings.get("speed", "标准"), 1.0)
	model.reset(api.get_seed())
	board.sync_body()
	if not local_id.is_empty():
		model.start()
		sounds.muted = not bool(api.config.get_own(&"sound", true))
		sounds.play_sound("start")
	for player: Dictionary in players:
		records[player.player_id] = {"score": 0, "done": false, "steps": 0}

func _unhandled_input(event: InputEvent) -> void:
	if not running or local_id.is_empty():
		return
	for binding: Array in [[&"move_left", Vector2i.LEFT], [&"move_right", Vector2i.RIGHT], [&"move_up", Vector2i.UP], [&"move_down", Vector2i.DOWN]]:
		if api.input.event_matches(event, binding[0]):
			model.queue_direction(binding[1])

func tick_game(delta: float) -> void:
	sounds.muted = not bool(api.config.get_own(&"sound", true))
	var duration: float = float(settings.get("duration", 120))
	if not local_id.is_empty() and not reported_done:
		timer += delta
		while timer >= (model.step_interval() / speed) and model.state == Model.State.RUNNING and elapsed < duration:
			timer -= (model.step_interval() / speed)
			board.previous_body = model.body.duplicate()
			var old_food: Vector2i = model.food
			var event: String = model.tick()
			steps += 1
			if event == "ate":
				board.ate(old_food)
				sounds.play_sound("eat")
			elif event in ["wall", "self"]:
				board.death_flash = 1.0
				sounds.play_sound("end")
			elif event == "won":
				sounds.play_sound("win")
		board.movement = clampf(timer / (model.step_interval() / speed), 0, 1)
		reporting += delta
		var done: bool = model.state != Model.State.RUNNING or elapsed >= duration
		if reporting >= 0.25 or done:
			reporting = 0.0
			send_action({"score": model.score, "steps": steps, "done": done})
			reported_done = done
	if api.is_host():
		var all_done: bool = true
		var scores: Dictionary = {}
		for id: String in records:
			scores[id] = records[id].score
			if not records[id].done and not disconnected.has(id):
				all_done = false
		if all_done or elapsed >= duration + 1.0:
			finish_scores(scores)

func handle_action(id: String, data: Dictionary) -> void:
	if not data.get("score") is int or not data.get("steps") is int or not data.get("done") is bool:
		return
	var previous: Dictionary = records[id]
	if previous.done or data.score < previous.score or data.steps < previous.steps or data.score < 0 or data.score > 4440 or data.score % 10 != 0 or data.steps > ceili((elapsed + 0.5) * speed / Model.MIN_INTERVAL) or data.score / 10 > data.steps:
		return
	records[id] = {"score": data.score, "steps": data.steps, "done": data.done}

func make_snapshot() -> Dictionary:
	return {"records": records.duplicate(true), "time": maxf(0, float(settings.get("duration", 120)) - elapsed)}

func render_game() -> void:
	if view.is_empty():
		return
	var progress: String = "观战中"
	if not local_id.is_empty():
		progress = api.i18n.text(&"hud.progress", {"score": model.score, "state": "本局已结束，等待结算" if reported_done else "每个食物 10 分"})
	status.text = api.i18n.text(&"hud.time", {"time": ceili(view.time), "progress": progress})
	for player: Dictionary in players:
		var record: Dictionary = view.records.get(player.player_id, {})
		update_standing(player.player_id, api.i18n.text(&"hud.player", {"player": player.name, "score": record.get("score", 0), "state": "结束" if record.get("done", false) else "挑战中"}))
