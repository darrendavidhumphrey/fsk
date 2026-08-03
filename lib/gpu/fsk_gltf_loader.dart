import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math.dart';
import '../fsk.dart';

/// A lightweight, dependency-free GLTF 2.0 loader for the FSK engine.
class FskGltfLoader {
  final FskScene scene;
  final String assetPath;
  late final String _basePath;

  Map<String, dynamic>? _json;
  final List<Uint8List> _buffers = [];
  final List<FskTextureInfo> _textures = [];

  FskGltfLoader(this.scene, this.assetPath) {
    final lastSlash = assetPath.lastIndexOf('/');
    _basePath = lastSlash != -1 ? assetPath.substring(0, lastSlash + 1) : '';
  }

  static Future<FskGroup> load(String assetPath, FskScene scene) async {
    final loader = FskGltfLoader(scene, assetPath);
    return await loader._parse();
  }

  Future<FskGroup> _parse() async {
    final String jsonString = await rootBundle.loadString(assetPath);
    _json = json.decode(jsonString);

    final rootGroup = FskGroup('gltf_root', scene);

    // 1. Load buffers safely
    final List<dynamic> jsonBuffers = _json!['buffers'] ?? [];
    for (final buf in jsonBuffers) {
      final uri = buf['uri'] as String;
      if (uri.startsWith('data:')) {
        _buffers.add(base64.decode(uri.split(',').last));
      } else {
        final byteData = await rootBundle.load('$_basePath$uri');
        _buffers.add(
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
        );
      }
    }

    // 2. Pre-load images
    final List<dynamic> jsonImages = _json!['images'] ?? [];
    for (int i = 0; i < jsonImages.length; i++) {
      final img = jsonImages[i];
      final String uri = img['uri'] as String;
      final info = await FSK().textureManager.createTextureFromAsset(
        'gltf_tex_${assetPath.hashCode}_$i',
        '${_basePath.replaceFirst("assets/", "")}$uri',
      );
      _textures.add(info);
    }

    // 3. Process scenes
    final int sceneIndex = (_json!['scene'] ?? 0).toInt();
    final List<dynamic> scenes = _json!['scenes'];
    final List<dynamic> sceneNodes = scenes[sceneIndex]['nodes'];
    for (final int nodeIdx in sceneNodes) {
      final node = _createNode((nodeIdx as num).toInt());
      if (node != null) rootGroup.children.add(node);
    }

    return rootGroup;
  }

  FskSceneObject? _createNode(int nodeIdx) {
    final nodeJson = _json!['nodes'][nodeIdx];
    final String name = nodeJson['name'] ?? 'node_$nodeIdx';

    FskSceneObject? node;
    if (nodeJson.containsKey('mesh')) {
      node = _createMesh((nodeJson['mesh'] as num).toInt(), name);
    } else {
      node = FskGroup(name, scene);
    }

    if (node is FskRenderableObject) {
      if (nodeJson.containsKey('translation')) {
        final List<dynamic> t = nodeJson['translation'];
        node.transformable.position = Vector3(
          t[0].toDouble(),
          t[1].toDouble(),
          t[2].toDouble(),
        );
      }
      if (nodeJson.containsKey('rotation')) {
        final List<dynamic> q = nodeJson['rotation'];
        final quat = Quaternion(
          q[0].toDouble(),
          q[1].toDouble(),
          q[2].toDouble(),
          q[3].toDouble(),
        );
        final euler = Vector3.zero();
        final m = quat.asRotationMatrix().storage;
        euler.y = asin(m[2].clamp(-1.0, 1.0));
        if (euler.y.abs() < 0.999) {
          euler.x = atan2(-m[5], m[8]);
          euler.z = atan2(-m[1], m[0]);
        } else {
          euler.x = atan2(m[3], m[4]);
        }
        node.transformable.rotation = euler;
      }
      if (nodeJson.containsKey('scale')) {
        final List<dynamic> s = nodeJson['scale'];
        node.transformable.scale = Vector3(
          s[0].toDouble(),
          s[1].toDouble(),
          s[2].toDouble(),
        );
      }
    }

    if (nodeJson.containsKey('children') && node is FskGroup) {
      for (final int childIdx in nodeJson['children']) {
        final child = _createNode((childIdx as num).toInt());
        if (child != null) node.children.add(child);
      }
    }
    return node;
  }

  FskSceneObject _createMesh(int meshIdx, String name) {
    final meshJson = _json!['meshes'][meshIdx];
    final primitives = meshJson['primitives'] as List<dynamic>;
    final group = FskGroup(name, scene);

    for (int i = 0; i < primitives.length; i++) {
      final mesh = FskIndexedMesh(
        '${name}_prim_$i',
        scene,
        shaderMaterial: FskShaderMaterial.pbr,
      );
      _buildPrimitive(primitives[i], mesh);
      group.children.add(mesh);
    }
    return group.children.length == 1 ? group.children[0] : group;
  }

  void _buildPrimitive(Map<String, dynamic> prim, FskIndexedMesh mesh) {
    final attrs = prim['attributes'] as Map<String, dynamic>;
    final int count = (_json!['accessors'][attrs['POSITION']]['count'] as num)
        .toInt();

    final positions = _getFloatData((attrs['POSITION'] as num).toInt());
    final normals = attrs.containsKey('NORMAL')
        ? _getFloatData((attrs['NORMAL'] as num).toInt())
        : Float32List(count * 3);
    final uvs = attrs.containsKey('TEXCOORD_0')
        ? _getFloatData((attrs['TEXCOORD_0'] as num).toInt())
        : Float32List(count * 2);

    final vertexData = Float32List(count * 12);
    for (int i = 0; i < count; i++) {
      final int b = i * 12;
      vertexData[b + 0] = positions[i * 3 + 0];
      vertexData[b + 1] = positions[i * 3 + 1];
      vertexData[b + 2] = positions[i * 3 + 2];
      vertexData[b + 3] = uvs[i * 2 + 0];
      vertexData[b + 4] = uvs[i * 2 + 1];
      vertexData[b + 5] = normals[i * 3 + 0];
      vertexData[b + 6] = normals[i * 3 + 1];
      vertexData[b + 7] = normals[i * 3 + 2];
      vertexData[b + 11] = 1.0;
    }

    mesh.vertices = vertexData;

    if (prim.containsKey('indices')) {
      final TypedData indices = _getIndexData((prim['indices'] as num).toInt());
      mesh.indices = indices;

      mesh.renderer.addSubMesh(
        SubMesh(indexCount: (indices as List).length, firstIndex: 0),
      );
    }

    if (prim.containsKey('material')) {
      _applyMaterial((prim['material'] as num).toInt(), mesh);
    }

    mesh.uploadToGpu();
    mesh.renderer.finalizeData();
  }

  void _applyMaterial(int matIdx, FskIndexedMesh mesh) {
    final mat = _json!['materials'][matIdx];
    final uniforms = mesh.uniforms as PbrUniforms;

    if (mat.containsKey('pbrMetallicRoughness')) {
      final pbr = mat['pbrMetallicRoughness'];
      if (pbr.containsKey('baseColorFactor')) {
        final List<dynamic> c = pbr['baseColorFactor'];
        uniforms.baseColorFactor = Vector3(
          c[0].toDouble(),
          c[1].toDouble(),
          c[2].toDouble(),
        );
      }
      if (pbr.containsKey('baseColorTexture')) {
        final int texIdx = (pbr['baseColorTexture']['index'] as num).toInt();
        final info =
            _textures[(_json!['textures'][texIdx]['source'] as num).toInt()];
        uniforms.texture = info.texture;
        uniforms.samplerOptions = info.samplerOptions;
      }
      if (pbr.containsKey('metallicRoughnessTexture')) {
        final int texIdx = (pbr['metallicRoughnessTexture']['index'] as num)
            .toInt();
        final info =
            _textures[(_json!['textures'][texIdx]['source'] as num).toInt()];
        uniforms.metallicRoughnessMap = info.texture;
      }
    }
    if (mat.containsKey('normalTexture')) {
      final int texIdx = (mat['normalTexture']['index'] as num).toInt();
      final info =
          _textures[(_json!['textures'][texIdx]['source'] as num).toInt()];
      uniforms.normalMap = info.texture;
    }
  }

  Float32List _getFloatData(int accessorIdx) {
    final acc = _json!['accessors'][accessorIdx];
    final int bvIdx = (acc['bufferView'] as num).toInt();
    final bv = _json!['bufferViews'][bvIdx];
    final buf = _buffers[(bv['buffer'] as num).toInt()];
    final int offset =
        (bv['byteOffset'] ?? 0).toInt() + (acc['byteOffset'] ?? 0).toInt();
    final int count = (acc['count'] as num).toInt();
    final int stride = (bv['byteStride'] ?? 0).toInt();

    int comps = (acc['type'] == 'VEC3') ? 3 : (acc['type'] == 'VEC2' ? 2 : 1);
    final result = Float32List(count * comps);
    final data = ByteData.view(buf.buffer, buf.offsetInBytes + offset);
    final actualStride = stride > 0 ? stride : comps * 4;

    for (int i = 0; i < count; i++) {
      for (int c = 0; c < comps; c++) {
        // FIX: Read directly from the start of the accessor view (Zero-based loop)
        result[i * comps + c] = data.getFloat32(
          (i * actualStride) + (c * 4),
          Endian.little,
        );
      }
    }
    return result;
  }

  TypedData _getIndexData(int accessorIdx) {
    final acc = _json!['accessors'][accessorIdx];
    final int bvIdx = (acc['bufferView'] as num).toInt();
    final bv = _json!['bufferViews'][bvIdx];
    final buf = _buffers[(bv['buffer'] as num).toInt()];
    final int offset =
        (bv['byteOffset'] ?? 0).toInt() + (acc['byteOffset'] ?? 0).toInt();
    final int count = (acc['count'] as num).toInt();
    final int type = (acc['componentType'] as num).toInt();

    final data = ByteData.view(buf.buffer, buf.offsetInBytes + offset);
    if (type == 5125) {
      // uint32
      final res = Uint32List(count);
      for (int i = 0; i < count; i++) {
        res[i] = data.getUint32(i * 4, Endian.little);
      }
      return res;
    } else {
      // uint16 or uint8
      final res = Uint16List(count);
      for (int i = 0; i < count; i++) {
        // FIX: Read directly from the start of the accessor view (Zero-based loop)
        res[i] = (type == 5123)
            ? data.getUint16(i * 2, Endian.little)
            : data.getUint8(i);
      }
      return res;
    }
  }
}
