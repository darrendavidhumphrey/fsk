import 'package:vector_math/vector_math_64.dart';
import 'polyline.dart';
import 'triangle_mesh.dart';
import 'mesh_factory.dart';

/// Represents a generic 3D solid, specifically a rectangular prism or cube.
///
/// This class is immutable and encapsulates the logic for creating its own faces
/// and the tessellated [TriangleMesh] used for picking.
class Solid {
  /// The list of polylines that define the faces of the solid.
  final List<Polyline> faces;

  /// A descriptive name for the solid (e.g., "Central Cube").
  final String name;

  /// The width, height, and depth of the solid.
  final Vector3 dimensions;

  /// A tessellated mesh of the solid's faces, used for ray-cast picking.
  late final TriangleMesh pickGeometry;

  /// Private constructor to create a solid from its constituent parts.
  /// The pick geometry is generated upon construction by the [MeshFactory].
  Solid._(this.faces, this.name, this.dimensions) {
    pickGeometry = MeshFactory.fromFaces(faces);
  }

  /// Creates a cube-shaped [Solid] centered at [center] with a given [size].
  factory Solid.cube({
    required Vector3 center,
    required double size,
    required String name,
  }) {
    return Solid.rectangular(
      center: center,
      dimensions: Vector3(size, size, size),
      name: name,
    );
  }

  /// Creates a rectangular [Solid] centered at [center] with the given [dimensions].
  factory Solid.rectangular({
    required Vector3 center,
    required Vector3 dimensions,
    required String name,
  }) {
    final double halfWidth = dimensions.x / 2.0;
    final double halfHeight = dimensions.y / 2.0;
    final double halfDepth = dimensions.z / 2.0;
    final List<Polyline> faces = [];

    // Define the 8 vertices relative to the center
    final v = [
      Vector3(center.x - halfWidth, center.y - halfHeight, center.z - halfDepth),
      Vector3(center.x + halfWidth, center.y - halfHeight, center.z - halfDepth),
      Vector3(center.x + halfWidth, center.y + halfHeight, center.z - halfDepth),
      Vector3(center.x - halfWidth, center.y + halfHeight, center.z - halfDepth),
      Vector3(center.x - halfWidth, center.y - halfHeight, center.z + halfDepth),
      Vector3(center.x + halfWidth, center.y - halfHeight, center.z + halfDepth),
      Vector3(center.x + halfWidth, center.y + halfHeight, center.z + halfDepth),
      Vector3(center.x - halfWidth, center.y + halfHeight, center.z + halfDepth),
    ];

    // Create faces with correct winding order for outward-facing normals
    faces.add(Polyline.fromVector3([v[0], v[1], v[2], v[3]])); // Front face
    faces.add(Polyline.fromVector3([v[5], v[4], v[7], v[6]])); // Back face
    faces.add(Polyline.fromVector3([v[1], v[5], v[6], v[2]])); // Right face
    faces.add(Polyline.fromVector3([v[4], v[0], v[3], v[7]])); // Left face
    faces.add(Polyline.fromVector3([v[3], v[2], v[6], v[7]])); // Top face
    faces.add(Polyline.fromVector3([v[4], v[5], v[1], v[0]])); // Bottom face

    return Solid._(faces, name, dimensions);
  }
}
