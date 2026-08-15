import 'package:flutter/material.dart' show Color, Colors;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// A utility class for creating thick line geometry as [Polyline]s or [FskMesh] objects.
class ThickLines {
  ThickLines._();

  /// Creates a single thick line segment as a [Polyline] quad.
  static Polyline createThickLineSegment(
    vm.Vector3 p1,
    vm.Vector3 p2,
    vm.Vector3 normal,
    double thickness,
  ) {
    double halfThickness = thickness / 2.0;
    if (halfThickness <= 0) {
      halfThickness = 0.01;
    }

    // Ensure the normal vector is normalized
    normal.normalize();

    // 1. Calculate segment direction
    vm.Vector3 segment = p2 - p1;
    segment.normalize(); // Normalize for consistent calculations

    // 2. Calculate displacement direction (perpendicular to segment and normal)
    vm.Vector3 displacementDirection = segment.cross(normal);
    displacementDirection.normalize(); // Ensure unit length

    // 3. Scale by half thickness
    vm.Vector3 displacement = displacementDirection * halfThickness;

    // 4. Generate the four vertices for the quad
    return Polyline.fromVector3([
      p1 + displacement,
      p1 - displacement,
      p2 - displacement,
      p2 + displacement,
    ]);
  }

  /// Creates a set of thick outlines with mitered joints from a quad.
  static List<Polyline> createThickOutline3DFromQuad(vm.Quad q, double thickness) {
    Polyline p = Polyline.fromVector3([q.point0, q.point1, q.point2, q.point3]);
    return createThickOutline3D(p, thickness);
  }

  /// Convert a polygon [Polyline] to a set of thick outlines with mitered joints.
  static List<Polyline> createThickOutline3D(Polyline polygon, double thickness) {
    List<Polyline> outlines = [];
    double halfThickness = thickness / 2.0;
    if (halfThickness <= 0) {
      halfThickness = 0.01;
    }

    if (polygon.length < 3) {
      // A polygon needs at least 3 vertices
      return outlines;
    }

    if (!polygon.planeIsValid) {
      // Ensure polygon has a valid normal
      return outlines;
    }

    // 1. Determine the polygon's normal vector
    vm.Vector3 normal = polygon.normal!;

    List<Edge> edges = [];

    final int length = polygon.length;
    for (int i = 0; i < length; i++) {
      vm.Vector3 prevPoint = polygon.getVector3((i - 1 + length) % length);
      vm.Vector3 currentPoint = polygon.getVector3(i);
      vm.Vector3 nextPoint = polygon.getVector3((i + 1) % length);

      // Direction vectors for incoming and outgoing segments
      vm.Vector3 incomingSegment = (currentPoint - prevPoint).normalized();
      vm.Vector3 outgoingSegment = (nextPoint - currentPoint).normalized();

      // 2. Calculate perpendicular vectors for incoming and outgoing segments
      vm.Vector3 incomingPerpendicular =
          incomingSegment.cross(normal).normalized();
      vm.Vector3 outgoingPerpendicular =
          outgoingSegment.cross(normal).normalized();

      // 3. Calculate the angle bisector
      vm.Vector3 miterDirection =
          (incomingPerpendicular + outgoingPerpendicular).normalized();

      // Check if the miter needs to be flipped for sharp corners (concave vs convex)
      double dotProduct = incomingSegment.dot(outgoingPerpendicular);
      if (dotProduct > 0) {
        miterDirection = -miterDirection;
      }

      // 4. Calculate miter length
      double miterLength =
          halfThickness / miterDirection.dot(incomingPerpendicular);

      // 5. Generate the mitered vertices
      vm.Vector3 miterOffset = miterDirection * miterLength;

      edges.add(Edge(currentPoint + miterOffset, currentPoint - miterOffset));
    }

    for (int i = 0; i < edges.length - 1; i++) {
      outlines.add(
        Polyline.fromVector3([
          edges[i].start,
          edges[i].end,
          edges[i + 1].end,
          edges[i + 1].start,
        ]),
      );
    }
    // Close the loop
    outlines.add(
      Polyline.fromVector3([
        edges[edges.length - 1].start,
        edges[edges.length - 1].end,
        edges[0].end,
        edges[0].start,
      ]),
    );
    return outlines;
  }

  // --- FskMesh Creation ---

  /// Directly creates an [FskMesh] from a list of edges.
  static FskMesh meshFromEdges(
    String id,
    FskSceneBase scene,
    List<Edge> edges,
    vm.Vector3 normal,
    double thickness, {
    Color color = Colors.white,
    FskShaderMaterial? material,
    bool bakeBarycentrics = false,
  }) {
    List<Polyline> outlines = [];
    for (var edge in edges) {
      outlines.add(
        createThickLineSegment(
          edge.start,
          edge.end,
          normal,
          thickness,
        ),
      );
    }

    return MeshFactory.meshFromColorOutlines(
      id,
      scene,
      outlines,
      color,
      material: material,
      bakeBarycentrics: bakeBarycentrics,
    );
  }

  /// Directly creates an [FskMesh] by forming a thick mitered outline around [polygon].
  static FskMesh meshFromOutline(
    String id,
    FskSceneBase scene,
    Polyline polygon,
    double thickness, {
    Color color = Colors.white,
    FskShaderMaterial? material,
    bool bakeBarycentrics = false,
  }) {
    final outlines = createThickOutline3D(polygon, thickness);
    return MeshFactory.meshFromColorOutlines(
      id,
      scene,
      outlines,
      color,
      material: material,
      bakeBarycentrics: bakeBarycentrics,
    );
  }
}
