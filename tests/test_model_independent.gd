extends SceneTree

var Model = load("res://scripts/snake_model.gd")
var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("QA FAIL: " + message)

func fresh():
	var m = Model.new()
	m.reset(12345)
	m.start()
	return m

func set_body(m, cells: Array) -> void:
	m.body.clear()
	for cell in cells:
		m.body.append(cell)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var m = fresh()
	m.size = Vector2i(5,2)
	m.reset(12345)
	for cell in m.body:
		check(cell.x>=0 and cell.y>=0 and cell.x<m.size.x and cell.y<m.size.y, "minimal reset body is in bounds")
	check(not m.body.has(m.food), "minimal reset food is outside snake")
	m = fresh()
	check(m.state == Model.State.RUNNING, "start enters RUNNING")
	check(m.body.size() >= 3, "starting snake has at least three cells")
	check(not m.body.has(m.food), "initial food lies outside snake")
	var original_head: Vector2i = m.body[0]
	var original_length: int = m.body.size()
	m.food = Vector2i(0, 0)
	check(m.tick() == "moved", "normal movement status")
	check(m.body[0] == original_head + Vector2i.RIGHT, "normal movement advances head right")
	check(m.body.size() == original_length, "normal movement preserves length")

	m = fresh()
	check(not m.queue_direction(Vector2i.LEFT), "180 degree reversal is rejected")
	check(not m.queue_direction(Vector2i.RIGHT), "redundant same direction rejected")
	check(not m.queue_direction(Vector2i.ZERO), "zero direction rejected")
	check(not m.queue_direction(Vector2i(1, 1)), "diagonal direction rejected")
	check(not m.queue_direction(Vector2i(2, 0)), "non-unit direction rejected")
	check(m.queue_direction(Vector2i.UP), "first legal turn accepted")
	check(not m.queue_direction(Vector2i.DOWN), "queued 180 degree reversal rejected")
	check(m.queue_direction(Vector2i.LEFT), "second legal turn accepted")
	check(not m.queue_direction(Vector2i.DOWN), "third queued turn rejected at queue bound")
	original_head = m.body[0]
	m.food = Vector2i(0, 0)
	m.tick()
	check(m.body[0] == original_head + Vector2i.UP, "tick consumes one queued turn only")
	check(m.turn_queue.size() == 1, "one queued turn remains")
	m.tick()
	check(m.body[0] == original_head + Vector2i.UP + Vector2i.LEFT, "next tick consumes second queued turn")

	m = fresh()
	set_body(m, [Vector2i(3,3),Vector2i(2,3),Vector2i(1,3)])
	m.food = Vector2i(4,3)
	var old_score: int = m.score
	check(m.tick() == "ate", "food reports ate")
	check(m.body.size() == 4 and m.body[-1] == Vector2i(1,3), "eating preserves tail and grows once")
	check(m.score > old_score, "food increases score")
	check(not m.body.has(m.food), "new food is not on grown snake")

	m = fresh()
	set_body(m, [Vector2i(m.size.x-1,4),Vector2i(m.size.x-2,4),Vector2i(m.size.x-3,4)])
	m.food = Vector2i(0,0)
	var before: Array = m.body.duplicate()
	check(m.tick() == "wall", "wall collision reported")
	check(m.state == Model.State.DEAD, "wall collision is terminal")
	check(m.body == before, "fatal wall tick preserves valid body")
	check(m.tick() == "idle", "terminal model does not continue moving")

	m = fresh()
	set_body(m, [Vector2i(3,3),Vector2i(3,4),Vector2i(4,4),Vector2i(4,3),Vector2i(5,3)])
	m.food = Vector2i(0,0)
	check(m.tick() == "self", "self collision reported")
	check(m.state == Model.State.DEAD, "self collision is terminal")

	m = fresh()
	set_body(m, [Vector2i(3,3),Vector2i(3,4),Vector2i(4,4),Vector2i(4,3)])
	m.food = Vector2i(0,0)
	check(m.tick() == "moved", "moving into vacated tail is legal")
	check(m.body[0] == Vector2i(4,3) and m.state == Model.State.RUNNING, "vacated-tail move survives")

	m = fresh()
	set_body(m, [Vector2i(3,3),Vector2i(3,4),Vector2i(4,4),Vector2i(4,3)])
	m.food = Vector2i(4,3)
	check(m.tick() == "self", "moving into retained growing tail is collision")

	m = fresh()
	m.size = Vector2i(2,2)
	set_body(m, [Vector2i(0,0),Vector2i(0,1),Vector2i(1,1)])
	m.direction = Vector2i.RIGHT
	m.food = Vector2i(1,0)
	check(m.tick() == "won", "eating final free cell wins")
	check(m.state == Model.State.WON and m.body.size() == 4, "full board terminal state and full length")
	check(not m.spawn_food(), "full-board food spawning returns false without looping")
	check(m.tick() == "idle", "won model is stable")

	m = fresh()
	m.queue_direction(Vector2i.UP)
	m.pause()
	before = m.body.duplicate()
	check(m.state == Model.State.PAUSED, "pause enters PAUSED")
	check(m.tick() == "idle" and m.body == before, "paused tick preserves body")
	m.resume()
	check(m.state == Model.State.RUNNING, "resume enters RUNNING")
	m.reset(12345)
	check(m.state == Model.State.READY and m.score == 0 and m.turn_queue.is_empty(), "reset clears state score and input")
	check(m.direction == Vector2i.RIGHT, "reset restores initial heading")

	m = fresh()
	var previous: float = m.step_interval()
	for score in [1, 2, 5, 10, 20, 50, 100, 1000, 1000000]:
		m.eaten = score
		var interval: float = m.step_interval()
		check(interval > 0.0 and interval <= previous, "speed remains positive and monotonic at score %d" % score)
		previous = interval
	var cap: float = m.step_interval()
	m.eaten = 2000000
	check(is_equal_approx(m.step_interval(), cap), "speed has a finite cap")

	m = fresh()
	m.size = Vector2i(7,5)
	set_body(m, [Vector2i(3,3),Vector2i(2,3),Vector2i(1,3)])
	for seed_value in range(400):
		m.rng.seed = seed_value
		check(m.spawn_food(), "food spawn succeeds with empty cells")
		check(m.food.x >= 0 and m.food.y >= 0 and m.food.x < m.size.x and m.food.y < m.size.y, "food is within rectangular board")
		check(not m.body.has(m.food), "food never overlaps snake")

	m = fresh()
	m.size = Vector2i(7,5)
	m.body.clear()
	var last := Vector2i(6,4)
	for y in range(5):
		for x in range(7):
			if Vector2i(x,y) != last:
				m.body.append(Vector2i(x,y))
	for seed_value in range(30):
		m.rng.seed = seed_value
		check(m.spawn_food() and m.food == last, "near-full-board food finds only free cell")

	print("INDEPENDENT_MODEL_QA: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		print("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
