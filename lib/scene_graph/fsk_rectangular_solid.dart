import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter/material.dart';
import 'package:fsk/scene_graph/fsk_mesh.dart';
import 'package:fsk/scene_graph/fsk_scene_object.dart';
import 'package:fsk/scene_graph/fsk_scene_base.dart';
import 'package:fsk/scene_graph/fsk_submesh.dart';
import 'package:fsk/fsk_singleton.dart';
import 'package:fsk/geometry/polyline.dart';
import 'package:fsk/geometry/mesh_factory.dart';
import 'package:fsk/gpu/fsk_vertex_buffer.dart';
import 'package:fsk/gpu/fsk_shader_material.dart';

/// Represents a generic 3D solid, specifically a rectangular prism or cube.
///
/// Refactored to be an [FskSceneObject] (via [FskMesh]) that caches its geometry
/// for drawing and hit testing.
class FskRectangularSolid extends FskMesh {
  /// Private constructor to create a solid from its constituent parts.
  /// The geometry is generated upon construction by the [MeshFactory].
  FskRectangularSolid._(
    super.id,
    super.scene,
    List<Polyline> faces,
    vm.Vector3 dimensions, {
    super.shaderMaterial,
    Color color = Colors.white,
  }) {
    vertices = MeshFactory.verticesFromSolidFaces(faces, color: color);
    uploadToGpu();
    renderer.setTexture(FSK().textureManager.solidTextureInfo);
    renderer.addFskSubMesh(FskSubMesh(
        count: vertices!.length ~/ FskVertexBuffer.componentCount, offset: 0));
    renderer.finalizeData();
  }

  /// Creates a cube-shaped [FskRectangularSolid] centered at [center] with a given [size].
  factory FskRectangularSolid.cube(
    {
    required String id,
    required FskSceneBase scene,
    required vm.Vector3 center,
    required double size,
    FskShaderMaterial? shaderMaterial,
    Color color = Colors.white,
  }) {
    return FskRectangularSolid.rectangular(
      id:id,
      scene: scene,
      center: center,
      dimensions: vm.Vector3(size, size, size),
      shaderMaterial: shaderMaterial,
      color: color,
    );
  }

  /// Creates a rectangular [FskRectangularSolid] centered at [center] with the given [dimensions].
  factory FskRectangularSolid.rectangular(
    {required String id,
    required FskSceneBase scene,
    required vm.Vector3 center,
    required vm.Vector3 dimensions,
    FskShaderMaterial? shaderMaterial,
    Color color = Colors.white,
  }) {
    final double halfWidth = dimensions.x / 2.0;
    final double halfHeight = dimensions.y / 2.0;
    final double halfDepth = dimensions.z / 2.0;
    final List<Polyline> faces = [];

    // Define the 8 vertices relative to the center
    // Standard RH system: +X=Right, +Y=Up, +Z=Back (towards camera)
    final v = [
      vm.Vector3(center.x - halfWidth, center.y - halfHeight, center.z - halfDepth), // 0: BL-Far
      vm.Vector3(center.x + halfWidth, center.y - halfHeight, center.z - halfDepth), // 1: BR-Far
      vm.Vector3(center.x + halfWidth, center.y + halfHeight, center.z - halfDepth), // 2: TR-Far
      vm.Vector3(center.x - halfWidth, center.y + halfHeight, center.z - halfDepth), // 3: TL-Far
      vm.Vector3(center.x - halfWidth, center.y - halfHeight, center.z + halfDepth), // 4: BL-Near
      vm.Vector3(center.x + halfWidth, center.y - halfHeight, center.z + halfDepth), // 5: BR-Near
      vm.Vector3(center.x + halfWidth, center.y + halfHeight, center.z + halfDepth), // 6: TR-Near
      vm.Vector3(center.x - halfWidth, center.y + halfHeight, center.z + halfDepth), // 7: TL-Near
    ];

    // Create faces with CCW winding order from the OUTSIDE for backface culling.
    faces.add(Polyline.fromVector3([v[4], v[5], v[6], v[7]])); // Front face (+Z)
    faces.add(Polyline.fromVector3([v[1], v[0], v[3], v[2]])); // Back face (-Z)
    faces.add(Polyline.fromVector3([v[7], v[6], v[2], v[3]])); // Top face (+Y)
    faces.add(Polyline.fromVector3([v[4], v[0], v[1], v[5]])); // Bottom face (-Y)
    faces.add(Polyline.fromVector3([v[5], v[1], v[2], v[6]])); // Right face (+X)
    faces.add(Polyline.fromVector3([v[0], v[4], v[7], v[3]])); // Left face (-X)

    return FskRectangularSolid._(id, scene, faces, dimensions, shaderMaterial: shaderMaterial, color: color);
  }
}
