extends Node3D
## One opaque, weather-responsive batch preserving the original puddle sites.
## Same photographic asphalt maps and UV scale as the underlying road.
const SHADER = preload("res://shaders/city_road_puddles.gdshader")
const Road = preload("res://scripts/photo_road_network.gd")
const SEGMENTS = 20
const HEIGHT = Road.Y + .006
const PATCHES = [
	Vector3(-174.0, 0.0, -145.0), Vector3(-116.0, 0.0, -88.0),
	Vector3(-58.0, 0.0, -23.0), Vector3(0.0, 0.0, -34.0),
	Vector3(58.0, 0.0, -88.0), Vector3(116.0, 0.0, -33.0),
	Vector3(174.0, 0.0, -88.0), Vector3(-174.0, 0.0, 88.0),
	Vector3(-116.0, 0.0, 145.0), Vector3(-58.0, 0.0, 88.0),
	Vector3(0.0, 0.0, 91.0), Vector3(58.0, 0.0, 146.0),
	Vector3(116.0, 0.0, 88.0), Vector3(174.0, 0.0, 147.0),
	Vector3(-34.0, 0.0, -116.0), Vector3(91.0, 0.0, 116.0)
]
var _batch: MeshInstance3D

func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("bitumen_color", load(Road.ROOT + "diffuse_2k.jpg"))
	material.set_shader_parameter("bitumen_normal", load(Road.ROOT + "nor_gl_2k.png"))
	material.set_shader_parameter("bitumen_roughness", load(Road.ROOT + "rough_2k.png"))
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in PATCHES.size():
		var radius_x := 1.75 if index % 2 == 0 else 2.35
		var radius_z := 3.65 if index % 3 == 0 else 2.45
		for segment in SEGMENTS:
			var first := _shoreline(TAU * float(segment) / SEGMENTS, index, radius_x, radius_z)
			var second := _shoreline(TAU * float(segment + 1) / SEGMENTS, index, radius_x, radius_z)
			# Godot's clockwise upward-facing triangles match PhotoRoadNetwork.
			for point in [Vector3.ZERO, first, second]:
				var at: Vector3 = PATCHES[index] + point + Vector3.UP * HEIGHT
				builder.set_normal(Vector3.UP)
				builder.set_uv(Vector2(at.x, at.z) / Road.TILE_METRES)
				builder.set_uv2(Vector2(0.0 if point == Vector3.ZERO else 1.0, 0.0))
				builder.set_tangent(Plane(1, 0, 0, -1))
				builder.add_vertex(at)
	_batch = MeshInstance3D.new()
	_batch.name = "WeatherPuddleBatch"
	_batch.mesh = builder.commit()
	_batch.material_override = material
	_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_batch.hide()
	add_child(_batch)

func set_surface_film(film: float) -> void:
	if is_instance_valid(_batch):
		_batch.visible = film > .06

func _shoreline(angle: float, index: int, radius_x: float, radius_z: float) -> Vector3:
	var wave := .84 + sin(angle * 3.0 + float(index) * .83) * .095
	wave += sin(angle * 7.0 - float(index) * .47) * .047
	wave += cos(angle * 11.0 + float(index) * .19) * .025
	return Vector3(cos(angle) * radius_x * wave, 0.0, sin(angle) * radius_z * wave)

func patch_count() -> int:
	return PATCHES.size() if is_instance_valid(_batch) else 0
