extends SceneTree
## Renderer-friendly real-authored Brickwater service-alley slice with the
## actual Cinder R9 gameplay visual: a staged Godot scene, not city gameplay.
## All architecture, service assets, wet road shader, shops and signs are the
## repository's original Brickwater components; masonry backing is a review set.

const BRICKWATER = preload("res://scripts/brickwater_alley.gd")
const ARCH = preload("res://scripts/brickwater_alley_architecture.gd")
const CINDER = preload("res://scripts/road_car_visual.gd")
const SHOTS = [
    ["01-brickwater-cinder-neon-night.png",21.5,
        Vector3(1.35,2.1,-10.7),Vector3(-.1,1.20,-1.55),59.0],
    ["02-brickwater-cinder-daylight.png",12.0,
        Vector3(1.35,2.1,-10.7),Vector3(-.1,1.20,-1.55),59.0],
    ["03-brickwater-cinder-front-threequarter.png",22.1,
        Vector3(2.12,1.68,-7.70),Vector3(-.15,1.0,-1.6),66.0],
]

func _initialize() -> void:
    create_timer(420.0,true,false,true).timeout.connect(func() -> void: quit(1))
    call_deferred("_capture")

func _fail(message:String) -> void:
    push_error("CINDER_BRICKWATER_SLICE: "+message)
    quit(1)

func _backdrop(stage:Node3D,wall:float,side:int) -> void:
    # Camera-only building backing is behind the existing actual panel kit.
    var quad:=QuadMesh.new()
    quad.size=Vector2(25,13)
    var view:=MeshInstance3D.new()
    view.name="StaticBuildingBackingWest" if side<0 else "StaticBuildingBackingEast"
    view.mesh=quad
    view.material_override=ARCH.alley_masonry(side<0)
    view.position=Vector3(wall,6.5,-1.9)
    view.rotation.y=PI*.5 if side<0 else -PI*.5
    stage.add_child(view)

func _capture() -> void:
    var target:=OS.get_environment("NIGHTGRID_CINDER_ALLEY_DIR")
    if not target.is_absolute_path() or DirAccess.dir_exists_absolute(target) \
            or DirAccess.make_dir_recursive_absolute(target)!=OK:
        _fail("Output must be new absolute directory")
        return
    if DisplayServer.get_name()=="headless" \
            or RenderingServer.get_current_rendering_method()!="forward_plus":
        _fail("Real Forward+ visible framebuffer is required")
        return
    var stage:=Node3D.new()
    stage.name="CurrentBrickwaterAuthoredAlleySlice"
    root.add_child(stage)
    var world_env:=WorldEnvironment.new()
    var environment:=Environment.new()
    environment.background_mode=Environment.BG_COLOR
    environment.background_color=Color("0b111f")
    environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color=Color("90a3c2")
    environment.ambient_light_energy=.65
    environment.reflected_light_source=Environment.REFLECTION_SOURCE_BG
    world_env.environment=environment
    stage.add_child(world_env)
    var sun:=DirectionalLight3D.new()
    sun.name="CinematicAlleySkyFill"
    sun.light_color=Color("c1d7ff")
    sun.light_energy=.55
    sun.shadow_enabled=true
    sun.rotation=Vector3(-.9,.4,0.0)
    stage.add_child(sun)
    _backdrop(stage,-2.86,-1)
    _backdrop(stage,2.86,1)
    var alley:=BRICKWATER.new() as Node3D
    alley.name="RealBrickwaterServiceAlley"
    alley.call("configure",-2.65,2.65)
    stage.add_child(alley)
    alley.call("install_repair_workshop")
    alley.call("install_ground_dressing")
    alley.call("install_upper_dressing")
    alley.call("install_lighting_and_signage")
    var car:=CINDER.new() as Node3D
    car.name="CurrentOriginalCinderR9"
    car.call("configure",Color("9c2338"))
    stage.add_child(car)
    car.position=Vector3(0,BRICKWATER.FLOOR_Y+.825,-2.05)
    car.rotation=Vector3.ZERO
    if car.get_node_or_null("Coachwork/FrontClip")==null:
        _fail("Real Cinder 3D imported coachwork missing")
        return
    var state:Dictionary=car.call("get_motion_state")
    if int(state.get("fixed_calipers",-1))!=4:
        _fail("Four original Cinder independently stationary calipers required")
        return
    var camera:=Camera3D.new()
    camera.near=.05
    camera.far=120.
    stage.add_child(camera)
    camera.make_current()
    var records:Array[Dictionary]=[]
    for view in SHOTS:
        var name:String=view[0]
        var hour:float=float(view[1])
        var is_night:=hour>=19.0
        alley.call("set_night_factor",1.0 if is_night else .05)
        environment.ambient_light_energy=.36 if is_night else .85
        sun.light_energy=.38 if is_night else 1.35
        car.call("set_lighting_hour",hour)
        car.call("update_motion",0.0,0.0,false,true,0.0,0.0,.3)
        camera.position=view[2]
        camera.fov=float(view[4])
        camera.look_at(view[3],Vector3.UP)
        await create_timer(.08).timeout
        for n in 3:
            await RenderingServer.frame_post_draw
        var frame:=root.get_texture().get_image()
        var path:=target.path_join(name)
        if frame==null or frame.is_empty() or frame.save_png(path)!=OK:
            _fail("No real Godot frame: "+name)
            return
        if FileAccess.get_file_as_bytes(path).size()<16000:
            _fail("Suspiciously small image: "+name)
            return
        print("CINDER_BRICKWATER_SLICE_FRAME ",name)
        records.append({"file":name,"sha256":FileAccess.get_sha256(path),"hour":hour,
            "camera":str(camera.global_position),"look":str(view[3]),
            "vehicle":"nightgrid.cinder_r9","location":"original Brickwater alley geometry",
            "capture_kind":"staged authored asset slice in actual Godot Forward+ renderer, not full game city"})
    var manifest:=FileAccess.open(target.path_join("manifest.json"),FileAccess.WRITE)
    if manifest==null:
        _fail("No provenance manifest")
        return
    manifest.store_string(JSON.stringify({"source_revision":OS.get_environment("NIGHTGRID_SOURCE_REVISION"),
        "engine":Engine.get_version_info().get("string"),
        "renderer":RenderingServer.get_current_rendering_method(),
        "driver":RenderingServer.get_current_rendering_driver_name(),
        "capture_kind":"authored Brickwater service alley assets; lightweight staging with original game car",
        "not_live_city_driving":true,"performance_comparable_to_native_gpu":false,
        "images":records},"\t"))
    manifest.close()
    print("CINDER_BRICKWATER_SLICE PASS")
    quit(0)
