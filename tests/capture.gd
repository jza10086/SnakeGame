extends SceneTree
## Developer-only deterministic rendering smoke test. Not loaded by the game.
## Uses the real rules and direction queue to collect food before screenshots.
var output_path := ProjectSettings.globalize_path("user://captures")
var game: Node

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--capture-dir" and i + 1 < args.size():
			output_path = args[i + 1]
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output_path)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await create_timer(0.8).timeout
	await capture("01-start.png")
	game.new_game()
	game.set_process(false)
	game.model.rng.seed = 71213
	for _step in 900:
		if game.model.eaten >= 14:
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
	var image := root.get_texture().get_image()
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
