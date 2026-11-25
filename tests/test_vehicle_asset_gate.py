"""Stdlib tests: CI can reject broken glTF/GLB even without Blender."""
import ast
import json
import struct
import sys
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools' / 'vehicles'))
from validate_gltf import AssetError, inspect, verify_manifest  # noqa: E402


def fixture(path: Path, *, degenerate=False, unit_normals=True, glb=False):
    positions = [(0., 0., 0.), (1., 0., 0.), (0., 1., 0.)]
    if degenerate:
        positions[-1] = (2., 0., 0.)
    normals = [(0., 0., 1. if unit_normals else 0.)] * 3
    uv = [(0., 0.), (1., 0.), (0., 1.)]
    vectors = [v for triple in positions for v in triple]
    nvec = [v for triple in normals for v in triple]
    tex = [v for pair in uv for v in pair]
    chunks = [struct.pack('<9f', *vectors), struct.pack('<9f', *nvec),
              struct.pack('<6f', *tex), struct.pack('<3H', 0, 1, 2)]
    chunks[-1] += b'\x00\x00'
    views = []
    offset = 0
    for c in chunks:
        views.append({'buffer': 0, 'byteOffset': offset, 'byteLength': len(c)})
        offset += len(c)
    doc = {
      'asset': {'version': '2.0'}, 'buffers': [{'byteLength': offset}],
      'bufferViews': views,
      'accessors': [
          {'bufferView': 0, 'componentType': 5126, 'count': 3, 'type': 'VEC3'},
          {'bufferView': 1, 'componentType': 5126, 'count': 3, 'type': 'VEC3'},
          {'bufferView': 2, 'componentType': 5126, 'count': 3, 'type': 'VEC2'},
          {'bufferView': 3, 'componentType': 5123, 'count': 3, 'type': 'SCALAR'}],
      'materials': [{'name': 'Original NightGrid paint'}],
      'nodes': [{'name': 'SocketHeadlampMount'}],
      'meshes': [{'primitives': [{'attributes': {'POSITION': 0, 'NORMAL': 1,
                            'TEXCOORD_0': 2}, 'indices': 3, 'material': 0}]}]
    }
    binary = b''.join(chunks)
    if glb:
        j = json.dumps(doc, separators=(',', ':')).encode()
        j += b' ' * (-len(j) % 4)
        payload = struct.pack('<I4s', len(j), b'JSON')+j
        payload += struct.pack('<I4s', len(binary), b'BIN\x00')+binary
        path.write_bytes(struct.pack('<4sII', b'glTF', 2, 12+len(payload))+payload)
    else:
        doc['buffers'][0]['uri'] = 'original.bin'
        (path.parent/'original.bin').write_bytes(binary)
        path.write_text(json.dumps(doc))
    return path


class TestAssetGate(unittest.TestCase):
    def test_gltf_ok_with_required_socket(self):
        with TemporaryDirectory() as d:
            path=fixture(Path(d)/'candidate.gltf')
            report=inspect(path, required_nodes=('SocketHeadlampMount',))
            self.assertEqual(report['triangles'],1)
            self.assertEqual(report['vertices'],3)
            self.assertEqual(report['bounds_max'],[1.,1.,0.])

    def test_binary_glb_ok(self):
        with TemporaryDirectory() as d:
            path=fixture(Path(d)/'candidate.glb',glb=True)
            self.assertEqual(inspect(path)['triangles'],1)

    def test_no_zero_area_triangles(self):
        with TemporaryDirectory() as d:
            path=fixture(Path(d)/'candidate.gltf',degenerate=True)
            with self.assertRaisesRegex(AssetError,'degenerate'):
                inspect(path)

    def test_no_invalid_normals(self):
        with TemporaryDirectory() as d:
            path=fixture(Path(d)/'candidate.gltf',unit_normals=False)
            with self.assertRaisesRegex(AssetError,'normals'):
                inspect(path)

    def test_budget_argument_is_validated(self):
        with TemporaryDirectory() as d:
            path=fixture(Path(d)/'candidate.gltf')
            with self.assertRaisesRegex(AssetError,'positive'):
                inspect(path,max_triangles=0)

    def test_missing_socket_is_rejected(self):
        with TemporaryDirectory() as d:
            path=fixture(Path(d)/'candidate.gltf')
            with self.assertRaisesRegex(AssetError,'Missing required sockets'):
                inspect(path,required_nodes=('SocketDoorLeft',))

    def test_no_path_traversal(self):
        with TemporaryDirectory() as d:
            path=fixture(Path(d)/'candidate.gltf')
            doc=json.loads(path.read_text())
            doc['buffers'][0]['uri']='../../secret.bin'
            path.write_text(json.dumps(doc))
            with self.assertRaisesRegex(AssetError,'escapes'):
                inspect(path)

    def test_corrupted_glb_is_rejected(self):
        with TemporaryDirectory() as d:
            path=fixture(Path(d)/'candidate.glb',glb=True)
            raw=bytearray(path.read_bytes())
            raw[0:4]=b'BAD!'
            path.write_bytes(raw)
            with self.assertRaisesRegex(AssetError,'magic'):
                inspect(path)

    def test_manifest_catches_wrong_hash(self):
        with TemporaryDirectory() as d:
            path=fixture(Path(d)/'candidate.glb',glb=True)
            manifest=Path(d)/'source.json'
            manifest.write_text(json.dumps({'files':{path.name:{'sha256':'00'}}}))
            with self.assertRaisesRegex(AssetError,'hash'):
                verify_manifest(manifest,path)

    def test_authoring_script_compiles_without_blender(self):
        source=(ROOT/'tools'/'vehicles'/'author_r9_optic_blender.py').read_text()
        ast.parse(source)
        self.assertIn('bpy.ops.wm.save_as_mainfile',source)
        self.assertIn('export_scene.gltf',source)


if __name__=='__main__':
    unittest.main()
