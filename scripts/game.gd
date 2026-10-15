extends Node
## State/input controller. Model owns rules, Board draws, HUD emits UI intentions.
const Model = preload("res://scripts/snake_model.gd")
const Store = preload("res://scripts/save_store.gd")
var model := Model.new()
var save := Store.new()
@onready var board: Node2D = $Board
@onready var hud: Control = $Interface/HUD
@onready var sound: Node = $Sound
var accumulator: float = 0.0
var presentation_time: float = 1.0
var previous_interval: float = 0.18
var resume_delay: float = 0.0
var round_best: int = 0
var touch_start := Vector2.ZERO
var touch_active: bool = false
var touch_id: int = -1
var end_pending: bool = false

func _ready() -> void:
	save.load_data()
	sound.muted = save.muted
	hud.set_sound_muted(save.muted)
	board.model = model
	model.reset()
	board.sync_body()
	hud.update_values(model.score, save.best)
	hud.primary_pressed.connect(_primary)
	hud.pause_pressed.connect(toggle_pause)
	hud.restart_pressed.connect(new_game)
	hud.sound_pressed.connect(toggle_sound)
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()

func _process(delta: float) -> void:
	if model.state != Model.State.RUNNING:
		return
	if resume_delay > 0.0:
		resume_delay = maxf(0.0, resume_delay - delta)
		return
	# Large OS hitches never fast-forward several unseen moves into a wall.
	accumulator += minf(delta, model.step_interval())
	presentation_time += delta
	board.movement = minf(1.0, presentation_time / (previous_interval * 0.70))
	if accumulator >= model.step_interval():
		var interval: float = model.step_interval()
		accumulator = minf(accumulator - interval, interval * 0.25)
		advance_step()

func advance_step() -> String:
	var old_food: Vector2i = model.food
	board.previous_body = model.body.duplicate()
	previous_interval = model.step_interval()
	var result: String = model.tick()
	if result == "idle":
		return result
	board.movement = 0.0
	presentation_time = 0.0
	if result == "ate" or result == "won":
		board.ate(old_food)
		save.record_score(model.score)
		hud.update_values(model.score, save.best)
		sound.play_sound("eat")
	if result == "wall" or result == "self" or result == "won":
		end_round(result)
	return result

func new_game() -> void:
	end_pending = false
	model.reset()
	model.start()
	board.sync_body()
	board.particles.clear()
	board.rings.clear()
	board.death_flash = 0.0
	board.food_pop = 1.0
	accumulator = 0.0
	presentation_time = 1.0
	resume_delay = 0.35
	_clear_touch()
	round_best = save.best
	hud.update_values(0, save.best)
	hud.hide_modal()
	sound.play_sound("start")

func toggle_pause() -> void:
	if model.state == Model.State.RUNNING:
		pause_game()
	elif model.state == Model.State.PAUSED:
		resume_game()

func pause_game() -> void:
	if model.state != Model.State.RUNNING:
		return
	model.pause()
	accumulator = 0.0
	board.sync_body()
	_clear_touch()
	hud.show_modal("paused", model.score, save.best)
	sound.play_sound("pause")

func resume_game() -> void:
	if model.state != Model.State.PAUSED:
		return
	model.resume()
	accumulator = 0.0
	presentation_time = 1.0
	resume_delay = 0.35
	_clear_touch()
	hud.hide_modal()

func end_round(reason: String) -> void:
	end_pending = true
	board.death_flash = 1.0
	board.movement = 1.0
	_clear_touch()
	sound.play_sound("win" if reason == "won" else "end")
	var expected_state: int = model.state
	await get_tree().create_timer(0.55).timeout
	if end_pending and model.state == expected_state:
		end_pending = false
		hud.show_modal("won" if reason == "won" else "dead", model.score, save.best, model.score > round_best)

func toggle_sound() -> void:
	save.muted = not save.muted
	sound.muted = save.muted
	hud.set_sound_muted(save.muted)
	save.save_data()

func _primary() -> void:
	if model.state == Model.State.PAUSED:
		resume_game()
	else:
		new_game()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if hud.overlay.visible and hud.modal_mode == "help":
			if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE]:
				hud.close_help()
				get_viewport().set_input_as_handled()
			return
		var requested := Vector2i.ZERO
		# Navigation keys use their logical code; some window/input backends
		# do not provide a physical scan code for arrows. WASD stays positional.
		match event.keycode:
			KEY_UP: requested = Vector2i.UP
			KEY_DOWN: requested = Vector2i.DOWN
			KEY_LEFT: requested = Vector2i.LEFT
			KEY_RIGHT: requested = Vector2i.RIGHT
		if requested == Vector2i.ZERO:
			match event.physical_keycode:
				KEY_UP, KEY_W: requested = Vector2i.UP
				KEY_DOWN, KEY_S: requested = Vector2i.DOWN
				KEY_LEFT, KEY_A: requested = Vector2i.LEFT
				KEY_RIGHT, KEY_D: requested = Vector2i.RIGHT
		if requested != Vector2i.ZERO:
			model.queue_direction(requested)
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_ESCAPE, KEY_SPACE]:
			if model.state == Model.State.READY:
				new_game()
			else:
				toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER:
			if model.state != Model.State.RUNNING:
				_primary()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_R:
			new_game()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_M:
			toggle_sound()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if model.state != Model.State.RUNNING:
			return
		if event.pressed and touch_id == -1 and board.board_rect.has_point(event.position):
			touch_start = event.position
			touch_active = true
			touch_id = event.index
		elif not event.pressed and event.index == touch_id:
			_handle_swipe(event.position)
			_clear_touch()
	elif event is InputEventScreenDrag and event.index == touch_id:
		_handle_swipe(event.position)

func _handle_swipe(point: Vector2) -> void:
	if not touch_active or model.state != Model.State.RUNNING:
		return
	var travel := point - touch_start
	if travel.length() < 24.0:
		return
	var requested: Vector2i
	if absf(travel.x) > absf(travel.y):
		requested = Vector2i(signi(int(travel.x)), 0)
	else:
		requested = Vector2i(0, signi(int(travel.y)))
	model.queue_direction(requested)
	touch_start = point

func _clear_touch() -> void:
	touch_active = false
	touch_id = -1
	touch_start = Vector2.ZERO

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready():
			pause_game()

func _on_resize() -> void:
	board.fit_to_viewport()
	board.sync_body()
	_clear_touch()
