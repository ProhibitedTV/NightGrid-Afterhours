"""Offline calibrated sparse multiview probe against a fixed Anubis sample.

Run with Blender --python this-file -- --capture --library /mnt/z/.../Visual --out ...
Then run the same file with the existing Anubis mesh Python and just --out.
"""
import argparse
import itertools
from pathlib import Path
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
from refine import load, sha, write

CASES = {
    "plant": "synaxis.office-plant-in-ceramic-pot.v1",
    "microwave": "synaxis.office-microwave-oven.v1",
    "fragmented_grate": "brickwater.metal-street-drainage-grate.v2",
    "dimensioned_grate": None,
}
SIZE = 448


def sources(library):
    refined = library / "refined-001"
    index = load(refined / "review-1024.json")
    indexed = {row["candidate"]: row["versions"][0] for row in index["rows"] if row.get("versions")}
    for name, key in CASES.items():
        if key is None:
            root = library / "Gen2/brickwater-grate-001"
            expected = load(root / "candidate.json")["outputs"]["lod0.glb"]["sha256"]
        else:
            record = indexed[key]
            root = refined / key / record["signature"]
            expected = record["outputs"]["lod0.glb"]["sha256"]
        source = root / "lod0.glb"
        if sha(source) != expected:
            raise ValueError(f"Existing mesh hash mismatch: {source}")
        yield name, source, expected


def capture(library, out):
    import bpy
    from math import cos, sin, tau
    from mathutils import Vector

    out.mkdir(parents=True, exist_ok=False)
    for name, source, digest in sources(library):
        start = time.perf_counter()
        target = out / name
        target.mkdir()
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(source))
        scene = bpy.context.scene
        corners = [obj.matrix_world @ Vector(p) for obj in scene.objects if obj.type == "MESH" for p in obj.bound_box]
        low = Vector([min(p[i] for p in corners) for i in range(3)])
        high = Vector([max(p[i] for p in corners) for i in range(3)])
        center = (low + high) * .5
        radius = (high - low).length * .5
        scene.render.engine = "CYCLES"
        scene.cycles.device = "CPU"
        scene.cycles.samples = 12
        scene.render.threads_mode = "FIXED"
        scene.render.threads = 2
        scene.render.resolution_x = SIZE
        scene.render.resolution_y = SIZE
        scene.render.resolution_percentage = 100
        scene.render.image_settings.color_mode = "RGBA"
        scene.render.film_transparent = True
        scene.world = bpy.data.worlds.new("Review background")
        scene.world.use_nodes = True
        scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .5
        for vector in (Vector((3,-2,4)), Vector((-2,2,3))):
            lamp = bpy.data.lights.new("Fixed soft source", "AREA")
            lamp.energy = 280 * radius ** 2
            lamp.size = 3 * radius
            source_node = bpy.data.objects.new("Soft source", lamp)
            scene.collection.objects.link(source_node)
            source_node.location = center + vector * radius
            source_node.rotation_euler = (-vector).to_track_quat("-Z", "Y").to_euler()
        cam = bpy.data.cameras.new("Calibrated viewpoint")
        cam.lens = 45
        observer = bpy.data.objects.new("Camera", cam)
        scene.collection.objects.link(observer)
        scene.camera = observer
        views = []
        for z in (.38, .82):
            for ix in range(8):
                angle = ix * tau / 8
                direction = Vector((cos(angle), sin(angle), z)).normalized()
                observer.location = center + direction * 3.4 * radius
                observer.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
                bpy.context.view_layer.update()
                depsgraph = bpy.context.evaluated_depsgraph_get()
                proj = observer.calc_matrix_camera(depsgraph, x=SIZE, y=SIZE) @ observer.matrix_world.inverted()
                half = (SIZE-1)/2
                matrix = [list(SIZE/2 * proj[0] + half * proj[3]),
                          list(-SIZE/2 * proj[1] + half * proj[3]), list(proj[3])]
                filename = f"view-{len(views):02}.png"
                scene.render.filepath = str(target / filename)
                bpy.ops.render.render(write_still=True)
                views.append({"file": filename, "camera_projection": matrix, "sha256": sha(target/filename)})
        write(target / "views.json", {"source_sha256": digest, "views": views,
              "bounds_xy_z": [list(low), list(high)], "capture_wall_seconds": time.perf_counter()-start})


def evaluate(out):
    import cv2
    import numpy as np

    cv2.setNumThreads(2)
    sift = cv2.SIFT_create(nfeatures=1200)
    matcher = cv2.BFMatcher(cv2.NORM_L2)
    rows = []
    for name in CASES:
        start = time.perf_counter()
        root = out / name
        data = load(root / "views.json")
        positions, descriptors, cameras = [], [], []
        for record in data["views"]:
            path = root / record["file"]
            if sha(path) != record["sha256"]:
                raise ValueError(f"Reference checksum mismatch: {path}")
            frame = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
            mask = cv2.erode((frame[:, :, 3] > 200).astype(np.uint8) * 255, np.ones((5,5),np.uint8))
            pointset, features = sift.detectAndCompute(cv2.cvtColor(frame, cv2.COLOR_BGRA2GRAY), mask)
            positions.append(np.array([point.pt for point in pointset]))
            descriptors.append(features)
            cameras.append(np.asarray(record["camera_projection"]))
        low, high = np.array(data["bounds_xy_z"])
        tolerance = (high - low) * .05
        cloud, errors = [], []
        for left, right in itertools.combinations(range(len(cameras)),2):
            azimuth_delta = abs(left%8 - right%8)
            if min(azimuth_delta, 8-azimuth_delta) > 1 or descriptors[left] is None or descriptors[right] is None:
                continue
            pairs = matcher.knnMatch(descriptors[left], descriptors[right], k=2)
            matched = [candidate for row in pairs if len(row) == 2
                      for candidate, other in [row] if candidate.distance < .73 * other.distance]
            if not matched:
                continue
            a = positions[left][[m.queryIdx for m in matched]]
            b = positions[right][[m.trainIdx for m in matched]]
            points = cv2.triangulatePoints(cameras[left], cameras[right], a.T, b.T).T
            with np.errstate(divide="ignore", invalid="ignore"):
                xyz = points[:,:3] / points[:,3:]
                xyz1 = np.column_stack((xyz,np.ones(len(xyz))))
                pred_a = xyz1 @ cameras[left].T
                pred_b = xyz1 @ cameras[right].T
                error = np.maximum(np.linalg.norm(pred_a[:,:2]/pred_a[:,2:]-a,axis=1),
                                   np.linalg.norm(pred_b[:,:2]/pred_b[:,2:]-b,axis=1))
            valid = (error < 2) & (pred_a[:,2] > 0) & (pred_b[:,2] > 0)
            valid &= ((xyz >= low-tolerance) & (xyz <= high+tolerance)).all(axis=1)
            cloud.extend(xyz[valid])
            errors.extend(error[valid])
        fused = len(np.unique(np.round(np.asarray(cloud) / max((high-low).max()*.004,1e-8),0),axis=0)) if cloud else 0
        rows.append({"case": name, "reference_views": len(cameras), "source_sha256": data["source_sha256"],
                     "features": sum(len(p) for p in positions), "retained_rays": len(cloud),
                     "unique_cells": fused, "median_reprojection_px": float(np.median(errors)) if errors else None,
                     "capture_wall_seconds": data["capture_wall_seconds"],
                     "sparse_cpu_seconds": time.perf_counter()-start})
    write(out / "probe.json", {"backend":"OpenCV SIFT and known-camera triangulation CPU",
          "scope":"Synthetic views of the same meshes. Calibrated sparse coverage, no dense mesh or real-world accuracy.",
          "opencv":cv2.__version__,"rows":rows})


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture", action="store_true")
    parser.add_argument("--library", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    tail = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else None
    args = parser.parse_args(tail)
    if args.capture and args.library is None:
        parser.error("--capture requires --library")
    if args.capture:
        capture(args.library, args.out)
    else:
        evaluate(args.out)
