import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:dart_stl/stl_reader.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../fsk_singleton.dart';
import '../logging.dart';
import '../vbo_filler.dart';
import '../gpu/fsk_vertex_buffer.dart';
import '../gpu/fsk_shader_material.dart';
import '../scene_graph/fsk_scene_base.dart';
import '../scene_graph/fsk_mesh.dart';
import '../scene_graph/fsk_stl_model.dart';
import '../scene_graph/fsk_submesh.dart';
import 'fsk_model_loader.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Represents a 3D model loaded from an STL file (ASCII or Binary).
class StlLoader extends FskModelLoader {
  /// The vertex buffer containing interleaved vertex data (Pos, Tex, Norm, Color).
  Float32List? vertices;

  /// The number of triangles in the model.
  int triangleCount = 0;

  StlLoader();

  /// Loads STL data from a [ByteData] buffer.
  /// Automatically detects whether the data is ASCII or Binary.
  void loadFromData(ByteData data) {
    if (data.lengthInBytes < 84) {
      // Could be a very small ASCII file
      try {
        final text = utf8.decode(data.buffer.asUint8List(0, data.lengthInBytes));
        if (text.trim().startsWith('solid')) {
          _loadASCII(text);
          return;
        }
      } catch (_) {}
      throw Exception('Invalid STL file: data too short');
    }

    // Heuristic: Binary STL has a 4-byte count at offset 80.
    // Total size should be 84 + count * 50.
    final count = data.getUint32(80, Endian.little);
    if (84 + count * 50 == data.lengthInBytes) {
      _loadBinary(data, count);
    } else {
      // Fallback to ASCII
      try {
        final text = utf8.decode(data.buffer.asUint8List(0, data.lengthInBytes));
        _loadASCII(text);
      } catch (e) {
        throw Exception('Failed to parse STL as Binary or ASCII: $e');
      }
    }
  }

  void _loadBinary(ByteData data, int count) {
    triangleCount = count;
    // Standard FSK stride is 12 floats (V3, T2, N3, C4)
    vertices = Float32List(count * 3 * FskVertexBuffer.componentCount);
    final filler = VboFiller(vertices!);

    int offset = 84;
    for (int i = 0; i < count; i++) {
      // Binary STL: Normal (3f), V1 (3f), V2 (3f), V3 (3f), Attr (2b) = 50 bytes
      vm.Vector3 normal = vm.Vector3(
        data.getFloat32(offset, Endian.little),
        data.getFloat32(offset + 4, Endian.little),
        data.getFloat32(offset + 8, Endian.little),
      );
      offset += FskVertexBuffer.componentCount;

      final v1 = vm.Vector3(
        data.getFloat32(offset, Endian.little),
        data.getFloat32(offset + 4, Endian.little),
        data.getFloat32(offset + 8, Endian.little),
      );
      offset += FskVertexBuffer.componentCount;

      final v2 = vm.Vector3(
        data.getFloat32(offset, Endian.little),
        data.getFloat32(offset + 4, Endian.little),
        data.getFloat32(offset + 8, Endian.little),
      );
      offset += FskVertexBuffer.componentCount;

      final v3 = vm.Vector3(
        data.getFloat32(offset, Endian.little),
        data.getFloat32(offset + 4, Endian.little),
        data.getFloat32(offset + 8, Endian.little),
      );
      offset += FskVertexBuffer.componentCount;

      offset += 2; // attribute byte count

      // If normal is not provided (all zeros), compute it from the face
      if (normal.length2 < 1e-9) {
        normal = (v2 - v1).cross(v3 - v1)..normalize();
      }

      // Add 3 vertices for the triangle. STL is unindexed vertex soup.
      // Use zero UVs and solid white color.
      filler.addV3T2N3C4(v1, vm.Vector2.zero(), normal, const Color(0xFFFFFFFF));
      filler.addV3T2N3C4(v2, vm.Vector2.zero(), normal, const Color(0xFFFFFFFF));
      filler.addV3T2N3C4(v3, vm.Vector2.zero(), normal, const Color(0xFFFFFFFF));
    }
  }

  void _loadASCII(String text) {
    final triangles = StlReader.fromSTL(text);
    if (triangles == null || triangles.isEmpty) {
      throw Exception('Failed to parse ASCII STL or file is empty');
    }

    triangleCount = triangles.length;
    vertices = Float32List(triangleCount * 3 * FskVertexBuffer.componentCount);
    final filler = VboFiller(vertices!);

    for (final tri in triangles) {
      // dart_stl uses vector_math_64 (double precision), FSK uses vector_math (32-bit).
      final v1 = vm.Vector3(tri.point0.x, tri.point0.y, tri.point0.z);
      final v2 = vm.Vector3(tri.point1.x, tri.point1.y, tri.point1.z);
      final v3 = vm.Vector3(tri.point2.x, tri.point2.y, tri.point2.z);

      // STL face normal from dart_stl
      vm.Vector3 normal = vm.Vector3(tri.normal.x, tri.normal.y, tri.normal.z);

      // If normal is missing or invalid, compute it
      if (normal.length2 < 1e-9) {
        normal = (v2 - v1).cross(v3 - v1)..normalize();
      }

      filler.addV3T2N3C4(v1, vm.Vector2.zero(), normal, const Color(0xFFFFFFFF));
      filler.addV3T2N3C4(v2, vm.Vector2.zero(), normal, const Color(0xFFFFFFFF));
      filler.addV3T2N3C4(v3, vm.Vector2.zero(), normal, const Color(0xFFFFFFFF));
    }
  }

  /// Entry point for loading an STL from assets.
  static Future<FskStlModel> loadFromAssets({
    required String assetFile,
    required FskSceneBase parentScene,
    required String sceneId,
    FskShaderMaterial? shaderMaterial,
    void Function(FskStlModel model)? onModelLoaded,
  }) async {
    final rootGroup = FskStlModel('${sceneId}_root', parentScene);

    try {
      final ByteData data = await rootBundle.load(assetFile);
      final loader = StlLoader();
      loader.loadFromData(data);

      final material = shaderMaterial ?? FskShaderMaterial.lighting;
      final mesh = loader.createMesh(parentScene, sceneId,
          shaderMaterial: material);

      // Automatically apply the solid white texture
      mesh.renderer.setTexture(FSK().textureManager.solidTextureInfo);

      mesh.rebuildPipelineIfNeeded();

      // STL files are typically Y-up. Correct to FSK convention.
      final correctionGroup = FskModelLoader.createCorrectionGroup(sceneId, parentScene);
      
      rootGroup.addNode(correctionGroup);
      correctionGroup.addNode(mesh);
      rootGroup.mesh = mesh;
      rootGroup.correctionGroup = correctionGroup;
      rootGroup.setLoaded();

      onModelLoaded?.call(rootGroup);
    } catch (e, s) {
      Logging.logError('StlLoader.loadFromAssets failed for "$assetFile": $e\n$s',
          source: 'StlLoader');
      rootGroup.setError(e.toString());
    }

    return rootGroup;
  }

  /// Creates an [FskMesh] from the loaded vertex data.
  FskMesh createMesh(FskSceneBase scene, String id,
      {FskShaderMaterial? shaderMaterial}) {
    final mesh = FskMesh(id, scene, shaderMaterial: shaderMaterial);

    mesh.vertices = vertices;
    mesh.uploadToGpu();
    mesh.renderer.addFskSubMesh(FskSubMesh(
      count: triangleCount * 3,
      offset: 0,
    ));
    mesh.renderer.finalizeData();

    return mesh;
  }
}
