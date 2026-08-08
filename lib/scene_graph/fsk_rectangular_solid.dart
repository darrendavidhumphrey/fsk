import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' as vm;

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
  }) {
    vertices = MeshFactory.verticesFromSolidFaces(faces);
    uploadToGpu();
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
  }) {
    return FskRectangularSolid.rectangular(
      id:id,
      scene: scene,
      center: center,
      dimensions: vm.Vector3(size, size, size),
      shaderMaterial: shaderMaterial,
    );
  }

  /// Creates a rectangular [FskRectangularSolid] centered at [center] with the given [dimensions].
  factory FskRectangularSolid.rectangular(
    {required String id,
    required FskSceneBase scene,
    required vm.Vector3 center,
    required vm.Vector3 dimensions,
    FskShaderMaterial? shaderMaterial,
  }) {
    final double halfWidth = dimensions.x / 2.0;
    final double halfHeight = dimensions.y / 2.0;
    final double halfDepth = dimensions.z / 2.0;
    final List<Polyline> faces = [];

    // Define the 8 vertices relative to the center
    final v = [
      vm.Vector3(center.x - halfWidth, center.y - halfHeight, center.z - halfDepth),
      vm.Vector3(center.x + halfWidth, center.y - halfHeight, center.z - halfDepth),
      vm.Vector3(center.x + halfWidth, center.y + halfHeight, center.z - halfDepth),
      vm.Vector3(center.x - halfWidth, center.y + halfHeight, center.z - halfDepth),
      vm.Vector3(center.x - halfWidth, center.y - halfHeight, center.z + halfDepth),
      vm.Vector3(center.x + halfWidth, center.y - halfHeight, center.z + halfDepth),
      vm.Vector3(center.x + halfWidth, center.y + halfHeight, center.z + halfDepth),
      vm.Vector3(center.x - halfWidth, center.y + halfHeight, center.z + halfDepth),
    ];

    // Create faces with CCW winding order for outward-facing normals (Right-handed Z-up)
    faces.add(Polyline.fromVector3([v[0], v[1], v[5], v[4]])); // Front face (-Y)
    faces.add(Polyline.fromVector3([v[2], v[3], v[7], v[6]])); // Back face (+Y)
    faces.add(Polyline.fromVector3([v[1], v[2], v[6], v[5]])); // Right face (+X)
    faces.add(Polyline.fromVector3([v[3], v[0], v[4], v[7]])); // Left face (-X)
    faces.add(Polyline.fromVector3([v[4], v[5], v[6], v[7]])); // Top face (+Z)
    faces.add(Polyline.fromVector3([v[1], v[0], v[3], v[2]])); // Bottom face (-Z)

    return FskRectangularSolid._(id, scene, faces, dimensions, shaderMaterial: shaderMaterial);
  }
}
