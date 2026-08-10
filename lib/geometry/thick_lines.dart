import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' as vm;

Polyline createThickLineSegment(
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
  // Vertex 0: P1 + displacement
  // Vertex 1: P1 - displacement
  // Vertex 2: P2 + displacement
  // Vertex 3: P2 - displacement

  return Polyline.fromVector3([
    p1 + displacement,
    p1 - displacement,
    p2 - displacement,
    p2 + displacement,
  ]);
}

List<Polyline> createThickOutline3DFromQuad(vm.Quad q, double thickness) {
  Polyline p = Polyline.fromVector3([q.point0, q.point1, q.point2, q.point3]);
  return createThickOutline3D(p, thickness);
}

List<Polyline> createThickOutline3DFromPoints(List<vm.Vector3> points,double thickness) {
  Polyline p = Polyline.fromVector3(points);
  return createThickOutline3D(p, thickness);
}

// Convert a polygon to a set of thick outlines with mitred joints
List<Polyline> createThickOutline3D(Polyline polygon, double thickness) {
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
    vm.Vector3 incomingPerpendicular = incomingSegment.cross(normal).normalized();
    vm.Vector3 outgoingPerpendicular = outgoingSegment.cross(normal).normalized();

    // 3. Calculate the angle bisector
    vm.Vector3 miterDirection = (incomingPerpendicular + outgoingPerpendicular)
        .normalized();

    // Check if the miter needs to be flipped for sharp corners (concave vs convex)
    // This is a simplified check; a more robust solution might involve the cross product of segments.
    double dotProduct = incomingSegment.dot(outgoingPerpendicular);
    if (dotProduct > 0) {
      // If miter direction is pointing "inward" for a convex corner
      miterDirection = -miterDirection;
    }

    // 4. Calculate miter length
    double miterLength =
        halfThickness / miterDirection.dot(incomingPerpendicular);

    // 5. Generate the mitered vertices
    vm.Vector3 miterOffset = miterDirection * miterLength;

    // For each point, we will have two vertices: outer and inner
    // This forms a quad for the segment.
    // Vertex 0: currentPoint + miterOffset (outer point)
    // Vertex 1: currentPoint - miterOffset (inner point)
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
