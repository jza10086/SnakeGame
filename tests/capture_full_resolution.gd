extends SceneTree
## Developer-only deterministic rendering smoke test. Not loaded by the game.
## Uses the real rules and direction queue to collect food before screenshots.
var output_path := ProjectSettings.globalize_path("user://captures")
var game: Node
var capture_view: SubViewport

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--capture-dir" and i + 1 < args.size():
			output_path = args[i + 1]
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output_path)
	game = load("res://scenes/main.tscn").instantiate()
	capture_view = SubViewport.new()
	capture_view.size = Vector2i(1440,900)
	capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_view)
	capture_view.add_child(game)
	var preview := TextureRect.new()
	preview.texture = capture_view.get_texture()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(preview)
	await create_timer(0.8).timeout
	await capture("01-start.png")
	game.new_game()
	game.set_process(false)
	game.model.rng.seed = 71213
	for _step in 900:
		if game.model.eaten >= 14 and bends() >= 4 and is_clear_head():
			break
		var move := direction_to_food()
		if move == Vector2i.ZERO:
			break
		game.model.queue_direction(move)
		var result: String = game.advance_step()
		if result in ["wall", "self", "won"]:
			break
		game.board.movement = 1.0
		await process_frame
	await create_timer(0.4).timeout
	print("PRESENTATION_REAL_STATE eaten=",game.model.eaten," score=",game.model.score," body=",game.model.body," food=",game.model.food," bends=",bends())
	await capture("02-playing.png")
	game.pause_game()
	await create_timer(0.25).timeout
	await capture("03-paused.png")
	game.hud._show_help()
	await create_timer(0.25).timeout
	await capture("04-help.png")
	game.hud.close_help()
	game.resume_game()
	for _i in 40:
		if game.model.state != game.Model.State.RUNNING:
			break
		game.advance_step()
	await create_timer(0.8).timeout
	await capture("05-game-over.png")
	print("CAPTURE_COMPLETE ", output_path)
	quit()

func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := capture_view.get_texture().get_image()
	var result := image.save_png(output_path.path_join(filename))
	print("CAPTURE ", filename, " error=", result)

func direction_to_food() -> Vector2i:
	var model: SnakeModel = game.model
	var origin: Vector2i = model.body[0]
	var frontier: Array[Vector2i] = [origin]
	var seen: Dictionary = {origin: Vector2i(-999, -999)}
	var index := 0
	while index < frontier.size():
		var cell := frontier[index]
		index += 1
		if cell == model.food:
			var path_cell := cell
			while seen[path_cell] != origin:
				path_cell = seen[path_cell]
			return path_cell - origin
		for step in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var next: Vector2i = cell + step
			if next.x < 0 or next.x >= model.size.x or next.y < 0 or next.y >= model.size.y:
				continue
			if seen.has(next) or model.body.has(next):
				continue
			if cell == origin and step == -model.direction:
				continue
			seen[next] = cell
			frontier.append(next)
	return Vector2i.ZERO

func bends() -> int:
	var count := 0
	for i in range(1,game.model.body.size()-1):
		if game.model.body[i-1]-game.model.body[i] != game.model.body[i]-game.model.body[i+1]:
			count += 1
	return count

func is_clear_head() -> bool:
	var head: Vector2i = game.model.body[0]
	if head.x < 3 or head.y < 3 or head.x >= game.model.size.x-3 or head.y >= game.model.size.y-3:
		return false
	for i in range(1,4):
		if game.model.body.has(head+game.model.direction*i): return false
	return true
