import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math.dart';

/// Represents a 3D edge with a starting point and an ending point.
@immutable
class Edge {
  /// The starting point of the edge.
  final Vector3 start;

  /// The ending point of the edge.
  final Vector3 end;

  /// Creates an edge with the given starting and ending points.
  Edge(this.start, this.end);

  /// Creates an edge with both points at the origin.
  Edge.zero() : start = Vector3.zero(), end = Vector3.zero();

  /// Transforms the edge by a given origin and X and Y axes.
  Edge transform(Vector3 origin3D, Vector3 xAxis, Vector3 yAxis) {
    Vector3 p1Transformed = origin3D + (xAxis * start.x) + (yAxis * start.y);
    Vector3 p2Transformed = origin3D + (xAxis * end.x) + (yAxis * end.y);

    return Edge(p1Transformed, p2Transformed);
  }

  /// Transforms a list of edges by a given origin and X and Y axes.
  static List<Edge> transformEdges(
      List<Edge> edges, Vector3 origin3D, Vector3 xAxis, Vector3 yAxis) {
    return edges
        .map((e) => e.transform(origin3D, xAxis, yAxis))
        .toList(growable: false);
  }

  // Determine if two edge lists are STRICTLY equal, meaning
  // that they contain the same set of edges, in the same order,
  // and the points in each edge are in the same order and each point
  // is exactly equal
  static bool edgeListsAreStrictlyEqual(List<Edge> set1, List<Edge> set2) {
    if (set1.length != set2.length) {
      return false;
    }

    for (int i = 0; i < set1.length; i++) {
      if ((set1[i].start != set2[i].start) || (set1[i].end != set2[i].end)) {
        return false;
      }
    }
    return true;
  }

  Edge copyWith({Vector3? start, Vector3? end}) {
    return Edge(
      start ?? this.start,
      end ?? this.end,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Edge &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}
