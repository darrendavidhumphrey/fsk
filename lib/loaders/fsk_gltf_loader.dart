import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../logging.dart';
import '../fsk_singleton.dart';
import '../gpu/fsk_texture_manager.dart';
import '../gpu/fsk_shader_material.dart';
import '../gpu/fsk_vertex_buffer.dart';
import '../scene_graph/fsk_scene_base.dart';
import '../scene_graph/fsk_scene_object.dart';
import '../scene_graph/fsk_group.dart';
import '../scene_graph/fsk_external_model.dart';
import '../scene_graph/fsk_indexed_mesh.dart';
import '../scene_graph/fsk_submesh.dart';
import '../shaders/pbr_shader.dart';
import 'fsk_model_loader.dart';

/// A lightweight, dependency-free GLTF 2.0 loader for the FSK engine.
class FskGltfLoader extends FskModelLoader {
  final FskSceneBase scene;
  final String assetPath;
  late final String _basePath;

  final int gltfUint32 = 5125;
  final int gltfUint16 = 5123;
  final int gltfUint8 = 5121;
  final int gltfFloat32 = 5126;


  Map<String, dynamic>? _json;
  final List<Uint8List> _buffers = [];
  final List<FskTextureInfo> _textures = [];

  FskGltfLoader(this.scene, this.assetPath) {
    final lastSlash = assetPath.lastIndexOf('/');
    _basePath = lastSlash != -1 ? assetPath.substring(0, lastSlash + 1) : '';
  }

  static Future<FskGroup> loadFromAssets({
    required String assetFile,
    required FskSceneBase parentScene,
    FskGroup? rootNode,
  }) async {
    final loader = FskGltfLoader(parentScene, assetFile);
    final rootGroup = rootNode ?? FskGroup('gltf_root', parentScene);

    try {
      await loader._parse(rootGroup: rootGroup);
      if (rootGroup is FskExternalModel) {
        rootGroup.setLoaded();
      }
    } catch (e, s) {
      Logging.logError('FskGltfLoader.loadFromAssets failed for "$assetFile": $e\n$s',
          source: 'FskGltfLoader');
      if (rootGroup is FskExternalModel) {
        rootGroup.setError(e.toString());
      }
    }
    return rootGroup;
  }

  Future<FskGroup> _parse({required FskGroup rootGroup}) async {
    final ByteData byteData = await rootBundle.load(assetPath);
    final Uint8List bytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    _json = json.decode(utf8.decode(bytes));

    final List<dynamic> jsonBuffers = _json!['buffers'] ?? [];
    for (int i = 0; i < jsonBuffers.length; i++) {
      final buf = jsonBuffers[i];
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

    final List<dynamic> jsonImages = _json!['images'] ?? [];
    for (int i = 0; i < jsonImages.length; i++) {
      final img = jsonImages[i];
      final info = await FSK().textureManager.createTextureFromAsset(
        'gltf_tex_${assetPath.hashCode}_$i',
        '${_basePath.replaceFirst("assets/", "")}${img['uri']}',
      );
      _textures.add(info);
    }

    final int sceneIndex = (_json!['scene'] ?? 0).toInt();
    final List<dynamic> scenes = _json!['scenes'];
    final List<dynamic> sceneNodes = scenes[sceneIndex]['nodes'];

    // GLTF models are often Y-up and facing +Z.
    final correctionGroup = FskModelLoader.createCorrectionGroup(rootGroup.id, scene);
    rootGroup.addNode(correctionGroup);
    if (rootGroup is FskExternalModel) {
      rootGroup.correctionGroup = correctionGroup;
    }

    for (final int nodeIdx in sceneNodes) {
      final node = _createNode((nodeIdx as num).toInt());
      if (node != null) correctionGroup.addNode(node);
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
        node.transformable.position = vm.Vector3(
          t[0].toDouble(),
          t[1].toDouble(),
          t[2].toDouble(),
        );
      }
      if (nodeJson.containsKey('rotation')) {
        final List<dynamic> q = nodeJson['rotation'];
        final quat = vm.Quaternion(
          q[0].toDouble(),
          q[1].toDouble(),
          q[2].toDouble(),
          q[3].toDouble(),
        );
        final euler = vm.Vector3.zero();
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
        node.transformable.scale = vm.Vector3(
          s[0].toDouble(),
          s[1].toDouble(),
          s[2].toDouble(),
        );
      }
    }

    if (nodeJson.containsKey('children') && node is FskGroup) {
      for (final childIdx in nodeJson['children']) {
        final child = _createNode((childIdx as num).toInt());
        if (child != null) node.addNode(child);
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
      group.addNode(mesh);
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

    final vertexData = Float32List(count * FskVertexBuffer.componentCount);
    for (int i = 0; i < count; i++) {
      final int b = i * FskVertexBuffer.componentCount;
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
      mesh.renderer.addFskSubMesh(
        FskSubMesh(count: (indices as dynamic).length, offset: 0),
      );
    } else {
      mesh.renderer.addFskSubMesh(FskSubMesh(count: count, offset: 0));
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
        uniforms.baseColorFactor = vm.Vector3(
          c[0].toDouble(),
          c[1].toDouble(),
          c[2].toDouble(),
        );
      }
      if (pbr.containsKey('baseColorTexture')) {
        final int texIdx = (pbr['baseColorTexture']['index'] as num).toInt();
        final info =
            _textures[(_json!['textures'][texIdx]['source'] as num).toInt()];
        mesh.renderer.setTexture(info); // Set on renderer to avoid override
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

    if (type == gltfUint32) {
      final res = Uint32List(count);
      for (int i = 0; i < count; i++) {
        res[i] = data.getUint32(i * 4, Endian.little);
      }
      return res;
    } else {
      final res = Uint16List(count);

      if (type == gltfUint16) {
        for (int i = 0; i < count; i++) {
          res[i] =  data.getUint16(i * 2, Endian.little);
        }
      } else {
        for (int i = 0; i < count; i++) {
          res[i] = data.getUint8(i);
        }
      }
      return res;
    }
  }
}
