class_name SnakeModel
extends RefCounted
## Deterministic grid rules. No scene tree, rendering, sound or save dependencies.

enum State { READY, RUNNING, PAUSED, DEAD, WON }
const START_LENGTH: int = 4
const MAX_TURNS: int = 2
const BASE_INTERVAL: float = 0.18
const MIN_INTERVAL: float = 0.075

var size: Vector2i = Vector2i(28, 16)
var body: Array[Vector2i] = []
var direction: Vector2i = Vector2i.RIGHT
var turn_queue: Array[Vector2i] = []
var food: Vector2i = Vector2i(-1, -1)
var score: int = 0
var state: State = State.READY
var rng := RandomNumberGenerator.new()
var eaten: int = 0
var last_reason: String = ""

func reset(seed_value: int = -1) -> void:
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	size.x = maxi(size.x, START_LENGTH + 1)
	size.y = maxi(size.y, 2)
	body.clear()
	var head := Vector2i(maxi(START_LENGTH - 1, size.x / 2), size.y / 2)
	for i in START_LENGTH:
		body.append(head - Vector2i(i, 0))
	direction = Vector2i.RIGHT
	turn_queue.clear()
	score = 0
	eaten = 0
	last_reason = ""
	state = State.READY
	spawn_food()
	# First food is inviting and reachable on the starting line.
	food = Vector2i(mini(head.x + 5, size.x - 1), head.y)

func start() -> void:
	if state == State.READY:
		state = State.RUNNING

func queue_direction(requested: Vector2i) -> bool:
	if state != State.RUNNING or absi(requested.x) + absi(requested.y) != 1:
		return false
	if turn_queue.size() >= MAX_TURNS:
		return false
	var planned: Vector2i = direction if turn_queue.is_empty() else turn_queue.back()
	if requested == planned or requested == -planned:
		return false
	turn_queue.append(requested)
	return true

func tick() -> String:
	if state != State.RUNNING:
		return "idle"
	if not turn_queue.is_empty():
		direction = turn_queue.pop_front()
	var head: Vector2i = body.front() + direction
	if head.x < 0 or head.x >= size.x or head.y < 0 or head.y >= size.y:
		return _die("wall")
	var growing: bool = head == food
	# Moving into the departing tail is legal when not eating.
	var occupied_count: int = body.size() if growing else body.size() - 1
	for i in occupied_count:
		if body[i] == head:
			return _die("self")
	body.push_front(head)
	if growing:
		score += 10
		eaten += 1
		if not spawn_food():
			state = State.WON
			last_reason = "won"
			turn_queue.clear()
			return "won"
		return "ate"
	body.pop_back()
	return "moved"

func spawn_food() -> bool:
	# Enumerating free cells is bounded and succeeds even at 447/448 occupancy.
	var free: Array[Vector2i] = []
	var occupied: Dictionary = {}
	for cell in body:
		occupied[cell] = true
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if not occupied.has(cell):
				free.append(cell)
	if free.is_empty():
		food = Vector2i(-1, -1)
		return false
	food = free[rng.randi_range(0, free.size() - 1)]
	return true

func pause() -> void:
	if state == State.RUNNING:
		state = State.PAUSED
		turn_queue.clear()

func resume() -> void:
	if state == State.PAUSED:
		state = State.RUNNING

func step_interval() -> float:
	return maxf(MIN_INTERVAL, BASE_INTERVAL - eaten * 0.003)

func speed_level() -> int:
	return mini(8, 1 + eaten / 5)

func _die(reason: String) -> String:
	state = State.DEAD
	last_reason = reason
	turn_queue.clear()
	return reason
