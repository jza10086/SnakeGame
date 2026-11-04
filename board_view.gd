extends Node3D
## 3D presentation of the classic X/Z grid. Collision and scoring stay in SnakeModel.
const Model: Script = preload("res://games/minigame/godot_party_default_snake_game/snake_model.gd")
const MINT: Color = Color("#79ebba")
const CORAL: Color = Color("#ff9b77")

var model: Model
var previous_body: Array[Vector2i] = []
var movement: float = 1.0
var death_flash: float = 0.0
var elapsed: float = 0.0
var food_pop: float = 1.0
var segments: Array[MeshInstance3D] = []
var links: Array[MeshInstance3D] = []
var eyes: Node3D
var food_visual: Node3D
var bite_ring: MeshInstance3D
var bite_age: float = 1.0
var snake_material: StandardMaterial3D
var segment_mesh: SphereMesh
var link_mesh: CylinderMesh
@onready var world: WorldEnvironment = %WorldEnvironment
@onready var sun: DirectionalLight3D = %Sun
@onready var camera: Camera3D = %Camera3D

func _ready() -> void:
	snake_material = _material(MINT, 0.26)
	segment_mesh = SphereMesh.new()
	segment_mesh.radius = 0.43
	segment_mesh.height = 0.78
	segment_mesh.radial_segments = 20
	segment_mesh.rings = 12
	link_mesh = CylinderMesh.new()
	link_mesh.top_radius = 0.32
	link_mesh.bottom_radius = 0.32
	link_mesh.height = 1.0
	link_mesh.radial_segments = 12
	_build_field()
	_build_food()
	_build_eyes()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()

func _material(color: Color, roughness: float = 0.7) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _mesh(parent: Node3D, shape: Mesh, material: Material, location: Vector3) -> MeshInstance3D:
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = shape
	visual.material_override = material
	visual.position = location
	parent.add_child(visual)
	return visual

func _box(dimensions: Vector3, location: Vector3, material: Material) -> void:
	var shape: BoxMesh = BoxMesh.new()
	shape.size = dimensions
	_mesh(self, shape, material, location)

func _build_field() -> void:
	var width: float = float(model.size.x)
	var depth: float = float(model.size.y)
	_box(Vector3(width + 0.8, 0.65, depth + 0.8), Vector3(0, -0.43, 0), _material(Color("#193e48")))
	# Two instanced tile meshes keep the full grid inexpensive to draw.
	for parity: int in 2:
		var tile: BoxMesh = BoxMesh.new()
		tile.size = Vector3(0.97, 0.12, 0.97)
		tile.material = _material(Color("#15343c") if parity == 0 else Color("#183b43"))
		var tiles: MultiMesh = MultiMesh.new()
		tiles.transform_format = MultiMesh.TRANSFORM_3D
		tiles.mesh = tile
		var cells: Array[Vector2i] = []
		for y: int in model.size.y:
			for x: int in model.size.x:
				if (x + y) % 2 == parity:
					cells.append(Vector2i(x, y))
		tiles.instance_count = cells.size()
		for index: int in cells.size():
			var location: Vector3 = cell_center(cells[index])
			location.y = -0.06
			tiles.set_instance_transform(index, Transform3D(Basis.IDENTITY, location))
		var visual: MultiMeshInstance3D = MultiMeshInstance3D.new()
		visual.multimesh = tiles
		add_child(visual)
	var rim: StandardMaterial3D = _material(Color("#4c9b98"), 0.35)
	for sign_value: float in [-1.0, 1.0]:
		_box(Vector3(width + 0.65, 0.2, 0.18), Vector3(0, 0.03, sign_value * (depth * 0.5 + 0.2)), rim)
		_box(Vector3(0.18, 0.2, depth + 0.65), Vector3(sign_value * (width * 0.5 + 0.2), 0.03, 0), rim)

func _build_food() -> void:
	food_visual = Node3D.new()
	add_child(food_visual)
	var apple: SphereMesh = SphereMesh.new()
	apple.radius = 0.34
	apple.height = 0.62
	_mesh(food_visual, apple, _material(CORAL, 0.22), Vector3.ZERO)
	var stem: CylinderMesh = CylinderMesh.new()
	stem.top_radius = 0.035
	stem.bottom_radius = 0.05
	stem.height = 0.23
	_mesh(food_visual, stem, _material(Color("#815941")), Vector3(0, 0.36, 0))
	var leaf: SphereMesh = SphereMesh.new()
	leaf.radius = 0.16
	leaf.height = 0.09
	var leaf_visual: MeshInstance3D = _mesh(food_visual, leaf, _material(MINT), Vector3(0.13, 0.4, 0))
	leaf_visual.scale.z = 0.5
	leaf_visual.rotation.z = 0.3
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.35
	ring.outer_radius = 0.4
	ring.rings = 32
	ring.ring_segments = 8
	bite_ring = _mesh(self, ring, _material(CORAL), Vector3.ZERO)
	bite_ring.hide()

func _build_eyes() -> void:
	eyes = Node3D.new()
	add_child(eyes)
	var white: StandardMaterial3D = _material(Color("#effff5"), 0.22)
	var dark: StandardMaterial3D = _material(Color("#102d2b"), 0.22)
	for sign_value: float in [-1.0, 1.0]:
		var eye: SphereMesh = SphereMesh.new()
		eye.radius = 0.13
		eye.height = 0.22
		_mesh(eyes, eye, white, Vector3(0.18, 0.31, sign_value * 0.2))
		var pupil: SphereMesh = SphereMesh.new()
		pupil.radius = 0.065
		pupil.height = 0.10
		_mesh(eyes, pupil, dark, Vector3(0.22, 0.39, sign_value * 0.2))

func _fit_camera() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = viewport_size.x / viewport_size.y
	var half_fov: float = tan(deg_to_rad(camera.fov * 0.5))
	var half_width: float = (model.size.x + 0.8) * 0.5
	var half_depth: float = (model.size.y + 0.8) * 0.5
	var distance: float = 0.0
	# Fit the nearest board corners into the perspective frustum, leaving room for the edge HUD.
	for x: float in [-half_width, half_width]:
		for z: float in [-half_depth, half_depth]:
			for y: float in [-0.8, 1.2]:
				var corner: Vector3 = camera.basis.inverse() * Vector3(x, y, z)
				var horizontal: float = absf(corner.x) / (half_fov * aspect * 0.9)
				var vertical: float = absf(corner.y) / (half_fov * 0.78)
				distance = maxf(distance, corner.z + maxf(horizontal, vertical))
	camera.position = camera.basis.z * distance

func cell_center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x - (model.size.x - 1) * 0.5, 0.43, cell.y - (model.size.y - 1) * 0.5)

func sync_body() -> void:
	previous_body = model.body.duplicate()
	movement = 1.0

func ate(cell: Vector2i) -> void:
	bite_ring.position = cell_center(cell)
	bite_ring.position.y = 0.1
	bite_age = 0.0
	food_pop = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	death_flash = maxf(0.0, death_flash - delta * 2.0)
	food_pop = minf(1.0, food_pop + delta * 5.0)
	bite_age += delta
	bite_ring.visible = bite_age < 0.45
	if bite_ring.visible:
		bite_ring.scale = Vector3.ONE * (1.0 + bite_age * 5.0)
	_sync_snake()
	food_visual.visible = model.food.x >= 0
	if food_visual.visible:
		food_visual.position = cell_center(model.food) + Vector3(0, 0.15 + sin(elapsed * 3.0) * 0.08, 0)
		food_visual.scale = Vector3.ONE * maxf(0.01, ease(food_pop, 0.5))
		food_visual.rotation.y = elapsed * 0.5

func _sync_snake() -> void:
	while segments.size() < model.body.size():
		segments.append(_mesh(self, segment_mesh, snake_material, Vector3.ZERO))
		if segments.size() > 1:
			links.append(_mesh(self, link_mesh, snake_material, Vector3.ZERO))
	var dead: bool = model.state == Model.State.DEAD
	snake_material.albedo_color = (Color("#b77c70") if dead else MINT).lerp(CORAL, death_flash * 0.7)
	for index: int in segments.size():
		segments[index].visible = index < model.body.size()
	for index: int in links.size():
		links[index].visible = index < model.body.size() - 1
	eyes.visible = not model.body.is_empty()
	for index: int in model.body.size():
		var current: Vector3 = cell_center(model.body[index])
		var previous: Vector3 = current
		if not previous_body.is_empty():
			previous = cell_center(previous_body[mini(index, previous_body.size() - 1)])
		segments[index].position = previous.lerp(current, clampf(movement, 0, 1))
		var taper: float = lerpf(1.0, 0.72, float(index) / maxf(1.0, model.body.size() - 1))
		segments[index].scale = Vector3.ONE * taper
		if index > 0:
			var link: MeshInstance3D = links[index - 1]
			var offset: Vector3 = segments[index - 1].position - segments[index].position
			link.position = (segments[index - 1].position + segments[index].position) * 0.5
			# A newly grown tail can overlap its predecessor during interpolation.
			link.visible = offset.length_squared() > 0.0001
			if link.visible:
				link.quaternion = Quaternion(Vector3.UP, offset.normalized())
				link.scale = Vector3(taper, offset.length(), taper)
	if eyes.visible:
		eyes.position = segments[0].position
		eyes.rotation.y = -atan2(float(model.direction.y), float(model.direction.x))
