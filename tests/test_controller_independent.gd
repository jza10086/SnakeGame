extends SceneTree
var game: Node
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func key(logical: Key, physical: Key, pressed: bool=true, echo: bool=false) -> void:
	var e := InputEventKey.new()
	e.keycode = logical
	e.physical_keycode = physical
	e.pressed = pressed
	e.echo = echo
	game._input(e)
func touch(index: int, pressed: bool, position: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.pressed = pressed
	e.position = position
	game._input(e)
func drag(index: int, position: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = position
	game._input(e)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.save.path = "user://qa-controller.cfg"
	check(game.model.state == game.Model.State.READY and game.hud.overlay.visible, "ready shows start modal")
	key(KEY_ENTER, KEY_ENTER)
	check(game.model.state == game.Model.State.RUNNING and not game.hud.overlay.visible, "Enter starts scene")
	var original_head: Vector2i = game.model.body[0]
	game._process(0.3)
	check(game.model.body[0] == original_head, "start grace period prevents immediate movement")
	game.resume_delay = 0.0
	game._process(100.0)
	check(game.model.body[0] == original_head+Vector2i.RIGHT, "huge process hitch moves only one cell")
	key(KEY_DOWN, 0)
	check(game.model.turn_queue == [Vector2i.DOWN], "logical-only arrow input reaches model")
	key(KEY_ESCAPE, KEY_ESCAPE, true, true)
	check(game.model.state == game.Model.State.RUNNING, "key echo does not pause")
	key(KEY_ESCAPE, KEY_ESCAPE, false)
	check(game.model.state == game.Model.State.RUNNING, "key release does not pause")
	key(KEY_ESCAPE, KEY_ESCAPE)
	check(game.model.state == game.Model.State.PAUSED and game.model.turn_queue.is_empty(), "pause clears queued turns")
	check(game.accumulator == 0.0, "pause clears timer accumulator")
	original_head = game.model.body[0]
	for i in 100: game._process(100.0)
	check(game.model.body[0] == original_head, "paused scene never fast-forwards")
	key(KEY_W, KEY_W)
	check(game.model.turn_queue.is_empty(), "movement while paused is not buffered")
	key(KEY_SPACE, KEY_SPACE)
	check(game.model.state == game.Model.State.RUNNING and game.resume_delay > 0.0, "Space resumes with safe delay")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.model.state == game.Model.State.PAUSED and game.hud.modal_mode == "paused", "focus loss pauses scene")
	game.hud._show_help()
	check(game.hud.modal_mode == "help", "help opens from pause")
	key(KEY_R,KEY_R)
	check(game.model.state == game.Model.State.PAUSED and game.hud.modal_mode == "help", "R in help cannot start hidden game")
	key(KEY_ESCAPE,KEY_ESCAPE)
	check(game.hud.modal_mode == "paused" and game.model.state == game.Model.State.PAUSED, "Escape closes help back to pause")
	game.new_game()
	var point: Vector2 = game.board.cell_center(Vector2i(10,8))
	touch(0,true,point)
	check(game.touch_active and game.touch_id == 0, "touch on board is tracked")
	touch(1,true,point+Vector2(10,10))
	check(game.touch_id == 0, "second touch cannot steal active gesture")
	drag(1,point+Vector2(0,-80))
	check(game.model.turn_queue.is_empty(), "inactive touch drag ignored")
	drag(0,point+Vector2(0,-10))
	check(game.model.turn_queue.is_empty(), "tiny swipe ignored")
	drag(0,point+Vector2(0,-80))
	check(game.model.turn_queue == [Vector2i.UP], "vertical swipe queues up")
	touch(0,false,point+Vector2(0,-80))
	check(not game.touch_active and game.touch_id == -1, "touch release clears gesture")
	touch(0,true,point)
	game.pause_game()
	check(not game.touch_active and game.touch_id == -1, "pause clears active touch")
	game.new_game()
	check(game.model.score == 0 and game.model.turn_queue.is_empty() and game.accumulator == 0 and not game.end_pending, "restart clears all transient state")
	game.resume_delay=0.0
	game.model.body.assign([Vector2i(27,8),Vector2i(26,8),Vector2i(25,8)])
	game.model.direction=Vector2i.RIGHT
	check(game.advance_step() == "wall" and game.end_pending, "death starts delayed modal")
	game.new_game()
	await create_timer(0.65).timeout
	check(game.model.state == game.Model.State.RUNNING and not game.hud.overlay.visible and not game.end_pending, "restart cancels stale death modal")
	var muted: bool = game.save.muted
	key(KEY_M,KEY_M)
	check(game.save.muted != muted and game.sound.muted == game.save.muted, "M changes audio state")
	game.new_game()
	check(game.save.muted != muted and game.sound.muted == game.save.muted, "restart preserves audio preference")
	print("INDEPENDENT_CONTROLLER_QA: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
