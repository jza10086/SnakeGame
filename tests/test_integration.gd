extends SceneTree
## Headless scene-level checks, including actual InputEvent routing.
var checks: int = 0
var failures: Array[String] = []
var game: Node

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func key(code: Key, echo_event: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo_event
	game._input(event)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_process(false)
	game.save.path = "user://integration_test_save.cfg"
	expect(game.model.state == SnakeModel.State.READY, "Initial state is READY")
	expect(game.hud.overlay.visible, "Ready overlay is visible")
	game.hud._show_help()
	expect(game.hud.modal_mode == "help", "Help opens")
	key(KEY_ESCAPE)
	expect(game.hud.modal_mode == "ready", "Escape closes help without starting")
	key(KEY_ENTER)
	expect(game.model.state == SnakeModel.State.RUNNING, "Enter starts")
	expect(not game.hud.overlay.visible, "Playing has no overlay")
	expect(game.resume_delay > 0, "New game has a short input grace period")
	key(KEY_UP, true)
	expect(game.model.turn_queue.is_empty(), "Keyboard repeat does not enqueue")
	key(KEY_UP)
	key(KEY_LEFT)
	expect(game.model.turn_queue.size() == 2, "Rapid deliberate corner inputs buffered")
	game.advance_step()
	expect(game.model.direction == Vector2i.UP, "Only one queued turn consumed per tick")
	key(KEY_ESCAPE)
	expect(game.model.state == SnakeModel.State.PAUSED, "Escape pauses")
	expect(game.model.turn_queue.is_empty(), "Pause clears queued turns")
	expect(game.accumulator == 0, "Pause clears accumulated time")
	var paused_body: Array[Vector2i] = game.model.body.duplicate()
	expect(game.advance_step() == "idle", "Paused model ignores tick")
	expect(game.model.body == paused_body, "Paused body does not move")
	key(KEY_SPACE)
	expect(game.model.state == SnakeModel.State.RUNNING, "Space resumes")
	expect(game.resume_delay > 0, "Resume has input grace period")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(game.model.state == SnakeModel.State.PAUSED, "Focus loss pauses safely")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	expect(game.model.state == SnakeModel.State.PAUSED, "Focus return never auto-resumes")
	game.resume_game()
	var touch := InputEventScreenTouch.new()
	touch.index = 4
	touch.pressed = true
	touch.position = game.board.board_rect.get_center()
	game._input(touch)
	expect(game.touch_active, "Touch starts inside board")
	var drag := InputEventScreenDrag.new()
	drag.index = 4
	drag.position = touch.position + Vector2(50, 0)
	game._input(drag)
	expect(game.model.turn_queue == [Vector2i.RIGHT], "Swipe becomes cardinal turn")
	game.pause_game()
	expect(not game.touch_active and game.touch_id == -1, "Pause clears touch state")
	game.new_game()
	expect(game.model.score == 0 and game.model.body.size() == 4, "Restart clears score and body")
	expect(game.model.turn_queue.is_empty(), "Restart clears buffered input")
	var logical_arrow := InputEventKey.new()
	logical_arrow.keycode = KEY_DOWN
	logical_arrow.physical_keycode = 0
	logical_arrow.pressed = true
	game._input(logical_arrow)
	expect(game.model.turn_queue == [Vector2i.DOWN], "Logical arrow works without a scan code")
	game.new_game()
	game.model.food = game.model.body[0] + Vector2i.RIGHT
	expect(game.advance_step() == "ate", "Controller eat step")
	expect(game.hud.score_label.text == "10", "Score HUD updates immediately")
	expect(game.model.body.size() == 5, "Eating grows body")
	var was_muted: bool = game.save.muted
	key(KEY_M)
	expect(game.save.muted != was_muted and game.sound.muted == game.save.muted, "Mute routes to saved audio state")
	game.model.body.assign([Vector2i(27, 8), Vector2i(26, 8), Vector2i(25, 8)])
	game.model.direction = Vector2i.RIGHT
	expect(game.advance_step() == "wall", "Controller handles collision")
	expect(game.model.state == SnakeModel.State.DEAD, "Collision ends round")
	await create_timer(0.65).timeout
	expect(game.hud.modal_mode == "dead" and game.hud.overlay.visible, "Game over overlay appears")
	key(KEY_ENTER)
	expect(game.model.state == SnakeModel.State.RUNNING, "Enter replays after game over")
	expect(not game.hud.overlay.visible, "Replay hides results")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://integration_test_save.cfg")
	print("INTEGRATION: %d assertions; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
