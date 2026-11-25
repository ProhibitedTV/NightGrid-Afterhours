import { createHash } from 'node:crypto';
import { mkdir, readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { join, resolve } from 'node:path';

const [source, destination, dependencies] = process.argv.slice(2);
if (!source || !destination || !dependencies) {
  throw new Error('Usage: node tools/prepare_pedestrian_models.mjs SOURCE DESTINATION DEPENDENCIES');
}

const require = createRequire(join(resolve(dependencies), 'package.json'));
const { NodeIO } = require('@gltf-transform/core');
const { ALL_EXTENSIONS } = require('@gltf-transform/extensions');
const { dequantize } = require('@gltf-transform/functions');
const { MeshoptDecoder } = require('meshoptimizer');

const models = {
  'casual-walker': 'ed578eebe688843f684391719158a08bf454665fd63f16df6b4745a57cffda9f',
  'dog-walker': 'a5408cf77434f9a74b112bc4924f07e1f86191edfac7f11eb4bb29b7d28b0ef4',
  'road-worker': 'a7b66ac6b58404ad4d076b25dd77412191ef2462c6f5f06e72eb9cd854d4d17b',
  hiker: 'bbf5f07bf23991a967cd29ef6c692d852047f1fc0d6860f689108e8e485b2f6e',
};
const digest = (bytes) => createHash('sha256').update(bytes).digest('hex');
await MeshoptDecoder.ready;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({
  'meshopt.decoder': MeshoptDecoder,
});
await mkdir(destination, { recursive: true });

for (const [id, expected] of Object.entries(models)) {
  const input = await readFile(join(source, id + '.glb'));
  if (digest(input) !== expected) throw new Error('Source digest mismatch for ' + id);
  const document = await io.readBinary(input);
  const root = document.getRoot();
  const meshopt = root.listExtensionsUsed().find((extension) => extension.extensionName === 'EXT_meshopt_compression');
  if (!meshopt) throw new Error('Missing source mesh compression for ' + id);
  meshopt.dispose();
  await document.transform(dequantize());
  if (!root.listSkins().some((skin) => skin.listJoints().length === 55) ||
      !root.listAnimations().some((animation) => animation.getName() === 'walk') ||
      !root.listTextures().some((texture) => texture.getMimeType() === 'image/ktx2')) {
    throw new Error('Converted model lost its rig, gait or textures for ' + id);
  }
  const output = join(destination, id + '.glb');
  await io.write(output, document);
  console.log(id, digest(await readFile(output)));
}
