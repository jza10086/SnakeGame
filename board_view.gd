extends Node3D
## 3D presentation of the classic X/Z grid. Collision and scoring stay in SnakeModel.
const Model: Script = preload("res://games/minigame/godot_party_default_snake_game/snake_model.gd")
const MINT: Color = Color("#79ebba")
const CORAL: Color = Color("#ff9b77")

var model: Model = Model.new()
var previous_body: Array[Vector2i] = []
var movement: float = 1.0
var death_flash: float = 0.0
var elapsed: float = 0.0
var food_pop: float = 1.0
var segments: Array[MeshInstance3D] = []
var links: Array[MeshInstance3D] = []
@onready var eyes: Node3D = $Field/Eyes
@onready var food_visual: Node3D = $Field/Food
@onready var bite_ring: MeshInstance3D = $Field/BiteRing
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
