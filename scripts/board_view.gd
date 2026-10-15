extends Node2D
## Presentation only. Reads model cells; never changes the game rules.
const BACKGROUND := Color("091a23")
const FIELD := Color("0d222b")
const GRID := Color("19343e")
const MINT := Color("79ebba")
const CORAL := Color("ff9b77")
var model: SnakeModel
var board_rect := Rect2()
var cell_size: float = 40.0
var previous_body: Array[Vector2i] = []
var movement: float = 1.0
var elapsed: float = 0.0
var particles: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var death_flash: float = 0.0
var food_pop: float = 1.0

func _process(delta: float) -> void:
	elapsed += delta
	death_flash = maxf(0.0, death_flash - delta * 2.0)
	food_pop = minf(1.0, food_pop + delta * 5.0)
	for i in range(particles.size() - 1, -1, -1):
		particles[i].life -= delta
		particles[i].position += particles[i].velocity * delta
		particles[i].velocity *= exp(-delta * 3.0)
		if particles[i].life <= 0.0:
			particles.remove_at(i)
	for i in range(rings.size() - 1, -1, -1):
		rings[i].age += delta
		if rings[i].age > 0.55:
			rings.remove_at(i)
	queue_redraw()

func fit_to_viewport() -> void:
	if model == null:
		return
	var viewport_size := get_viewport_rect().size
	var margin := clampf(viewport_size.x * 0.035, 18.0, 54.0)
	var top := 118.0
	var available := viewport_size - Vector2(margin * 2.0, top + margin)
	cell_size = minf(available.x / model.size.x, available.y / model.size.y)
	var dimensions := Vector2(model.size) * cell_size
	board_rect = Rect2(Vector2((viewport_size.x - dimensions.x) * 0.5, top + (available.y - dimensions.y) * 0.5), dimensions)

func cell_center(cell: Vector2i) -> Vector2:
	return board_rect.position + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size

func sync_body() -> void:
	previous_body = model.body.duplicate()
	movement = 1.0

func ate(cell: Vector2i) -> void:
	var location := cell_center(cell)
	rings.append({"position": location, "age": 0.0})
	for i in 12:
		var angle := i * TAU / 12.0 + 0.17
		particles.append({"position": location, "velocity": Vector2.from_angle(angle) * (55.0 + (i % 3) * 25.0), "life": 0.3 + (i % 4) * 0.06, "max_life": 0.5, "radius": 2.0 + i % 2})
	food_pop = 0.0

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), BACKGROUND)
	# Wide, exceptionally subtle atmospheric light. No dashboard container.
	for i in range(20, 0, -1):
		var radius := i * viewport_size.x * 0.026
		draw_circle(Vector2(viewport_size.x * 0.17, viewport_size.y * 0.34), radius, Color(0.09, 0.27, 0.28, 0.005))
	if model == null:
		return
	fit_to_viewport()
	var style := StyleBoxFlat.new()
	style.bg_color = FIELD
	style.set_corner_radius_all(6)
	draw_style_box(style, board_rect)
	for x in range(1, model.size.x):
		var start := board_rect.position + Vector2(x * cell_size, 0)
		draw_line(start, start + Vector2(0, board_rect.size.y), Color(GRID, 0.45), 1.0)
	for y in range(1, model.size.y):
		var start := board_rect.position + Vector2(0, y * cell_size)
		draw_line(start, start + Vector2(board_rect.size.x, 0), Color(GRID, 0.45), 1.0)
	# Tiny intersections make the field tactile without overpowering the snake.
	for y in range(2, model.size.y, 4):
		for x in range(2, model.size.x, 4):
			draw_circle(board_rect.position + Vector2(x, y) * cell_size, 1.4, Color("2a444c"))
	draw_rect(board_rect, Color("26404a"), false, 1.0)
	_draw_corner_marks()
	if model.food.x >= 0:
		_draw_food()
	_draw_snake()
	for ring in rings:
		var t: float = ring.age / 0.55
		draw_arc(ring.position, cell_size * (0.3 + t * 0.9), 0, TAU, 48, Color(CORAL, (1.0 - t) * 0.4), 1.4, true)
	for particle in particles:
		draw_circle(particle.position, particle.radius, Color(CORAL, clampf(particle.life / particle.max_life, 0.0, 1.0)))
	if death_flash > 0:
		draw_rect(board_rect, Color(1.0, 0.39, 0.3, death_flash * 0.07))

func _draw_corner_marks() -> void:
	var accent := Color("4a6b71")
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var point: Vector2 = board_rect.position + board_rect.size * corner
		var dx := -1.0 if corner.x > 0 else 1.0
		var dy := -1.0 if corner.y > 0 else 1.0
		draw_line(point, point + Vector2(dx * 16.0, 0), accent, 1.5, true)
		draw_line(point, point + Vector2(0, dy * 16.0), accent, 1.5, true)

func _draw_food() -> void:
	var point := cell_center(model.food)
	var breathing := 1.0 + sin(elapsed * 3.0) * 0.045
	var radius := cell_size * 0.255 * breathing * ease(food_pop, 0.5)
	for i in range(5, 0, -1):
		draw_circle(point, radius + i * cell_size * 0.11, Color(CORAL, 0.018))
	draw_circle(point + Vector2(0, 3), radius + 1.0, Color("59352d"))
	draw_circle(point, radius, CORAL)
	draw_circle(point + Vector2(-radius * 0.28, -radius * 0.3), radius * 0.29, Color("ffd9b3"))
	draw_arc(point, cell_size * 0.40, -1.1 + elapsed * 0.15, 0.5 + elapsed * 0.15, 20, Color(CORAL, 0.28), 1.0, true)

func _draw_snake() -> void:
	if model.body.is_empty():
		return
	var points := PackedVector2Array()
	var progress := clampf(movement, 0.0, 1.0)
	for i in model.body.size():
		var current := cell_center(model.body[i])
		var old := current
		if not previous_body.is_empty():
			old = cell_center(previous_body[mini(i, previous_body.size() - 1)])
		points.append(old.lerp(current, progress))
	var width := cell_size * 0.73
	# One complete shadow pass stays behind every segment, never cutting dark
	# crescents into a neighboring capsule along horizontal runs.
	var shadow := Vector2(0, cell_size * 0.09)
	for i in range(points.size() - 1, -1, -1):
		var ratio := 1.0 - float(i) / maxf(1.0, points.size() - 1)
		var segment_width := width * (0.72 + ratio * 0.28)
		if i < points.size() - 1:
			draw_line(points[i] + shadow, points[i + 1] + shadow, Color(0, 0, 0, 0.20), segment_width + 2.0, true)
		draw_circle(points[i] + shadow, segment_width * 0.5 + 1.0, Color(0, 0, 0, 0.16))
	# Connected opaque capsules; the tail gently tapers.
	for i in range(points.size() - 1, -1, -1):
		var ratio := 1.0 - float(i) / maxf(1.0, points.size() - 1)
		var color := Color("36ad8e").lerp(MINT, ratio * 0.8)
		if model.state == SnakeModel.State.DEAD:
			color = color.lerp(Color("ad7b70"), 0.45)
		var segment_width := width * (0.72 + ratio * 0.28)
		if i < points.size() - 1:
			draw_line(points[i], points[i + 1], color, segment_width, true)
		draw_circle(points[i], segment_width * 0.5, color)
	# Sparse texture is drawn last so it remains light and intentional.
	for i in range(points.size() - 1, 0, -1):
		if i > 0 and i < points.size() - 1:
			draw_circle(points[i] - Vector2(0, cell_size * 0.10), cell_size * 0.055, Color(0.75, 1.0, 0.85, 0.16))
	var head: Vector2 = points[0]
	var facing := Vector2(model.direction)
	var side := Vector2(-facing.y, facing.x)
	for sign_value in [-1.0, 1.0]:
		var eye: Vector2 = head + facing * cell_size * 0.13 + side * float(sign_value) * cell_size * 0.17
		draw_circle(eye, cell_size * 0.093, Color("cfffe2"))
		draw_circle(eye + facing * cell_size * 0.026, cell_size * 0.048, Color("183d38"))
		draw_circle(eye + facing * cell_size * 0.034 - Vector2(0, 1), cell_size * 0.013, Color.WHITE)
