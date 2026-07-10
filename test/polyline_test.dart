import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:fsk/geometry/polyline.dart';

void main() {
  group('Polyline', () {
    group('Constructors and Properties', () {
      test('fromVector2 creates a valid polyline on the XY plane', () {
        final points = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)];
        final polyline = Polyline.fromVector2(points);
        expect(polyline.length, 3);
        expect(polyline.getVector3(0), Vector3(0, 0, 0));
        expect(polyline.getVector3(1), Vector3(1, 0, 0));
        expect(polyline.getVector3(2), Vector3(1, 1, 0));
        expect(polyline.planeIsValid, isTrue);
        expect(polyline.normal, Vector3(0, 0, 1));
      });

      test('fromVector3 creates a valid polyline', () {
        final points = [Vector3(0, 0, 5), Vector3(1, 0, 5), Vector3(1, 1, 5)];
        final polyline = Polyline.fromVector3(points);
        expect(polyline.length, 3);
        expect(polyline.getVector3(1), Vector3(1, 0, 5));
        expect(polyline.planeIsValid, isTrue);
        expect(polyline.normal, Vector3(0, 0, 1));
      });

      test('fromPolyline creates an identical copy', () {
        final original = Polyline.fromVector3([Vector3(0,0,0), Vector3(1,0,0), Vector3(1,1,0)]);
        final copy = Polyline.fromPolyline(original);
        expect(copy, equals(original));
        expect(identical(copy, original), isFalse);
      });

      test('fromIndices creates a correct sub-polyline', () {
        final original = Polyline.fromVector3([
          Vector3(0, 0, 0), // index 0
          Vector3(1, 0, 0), // index 1
          Vector3(1, 1, 0), // index 2
          Vector3(0, 1, 0), // index 3
        ]);
        final sub = Polyline.fromIndices(original, [0, 2]);
        expect(sub.length, 2);
        expect(sub.getVector3(0), Vector3(0, 0, 0));
        expect(sub.getVector3(1), Vector3(1, 1, 0));
      });

      test('plane is invalid for fewer than 3 vertices', () {
        final points = [Vector2(0, 0), Vector2(1, 0)];
        final polyline = Polyline.fromVector2(points);
        expect(polyline.length, 2);
        expect(polyline.planeIsValid, isFalse);
        expect(polyline.normal, isNull);
      });

      test('plane is invalid for collinear vertices', () {
        final points = [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(2, 0, 0)];
        final polyline = Polyline.fromVector3(points);
        expect(polyline.planeIsValid, isFalse);
        expect(polyline.normal, isNull);
      });
    });

    group('getValidVertexIndices', () {
      test('returns all indices for a valid polyline', () {
        final poly = Polyline.fromVector3([
          Vector3(0, 0, 0),
          Vector3(1, 0, 0),
          Vector3(1, 1, 0),
        ]);
        expect(poly.getValidVertexIndices(), equals([0, 1, 2]));
      });

      test('removes an exactly duplicate vertex', () {
        final poly = Polyline.fromVector3([
          Vector3(0, 0, 0),
          Vector3(1, 0, 0),
          Vector3(1, 0, 0), // Degenerate vertex
          Vector3(1, 1, 0),
        ]);
        // The edge from index 1 to 2 is degenerate, so index 1 is removed.
        expect(poly.getValidVertexIndices(), equals([0, 2, 3]));
      });

      test('removes a very close vertex', () {
        final poly = Polyline.fromVector3([
          Vector3(0, 0, 0),
          Vector3(1, 0, 0),
          Vector3(1.0000001, 0.0000001, 0), // Degenerate vertex
          Vector3(1, 1, 0),
        ]);
        // The edge from index 1 to 2 is degenerate, so index 1 is removed.
        expect(poly.getValidVertexIndices(), equals([0, 2, 3]));
      });

      test('handles wrap-around duplicate vertex', () {
        final poly = Polyline.fromVector3([
          Vector3(0, 0, 0),
          Vector3(1, 0, 0),
          Vector3(0, 0, 0), // Degenerate vertex (same as start)
        ]);
        // The edge from index 2 to 0 (wrap) is degenerate, so index 2 is removed.
        expect(poly.getValidVertexIndices(), equals([0, 1]));
      });
    });

    group('containsPoint', () {
      // A simple square on the XY plane from (0,0,0) to (1,1,0)
      final square = Polyline.fromVector2(
          [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]);

      test('returns true for a point inside the polygon', () {
        expect(square.containsPoint(Vector3(0.5, 0.5, 0)), isTrue);
      });

      test('returns false for a point outside the polygon', () {
        expect(square.containsPoint(Vector3(2, 0.5, 0)), isFalse);
      });

      test('returns true for a point on an edge', () {
        // The algorithm should be inclusive of the boundary
        expect(square.containsPoint(Vector3(0.5, 0, 0)), isTrue);
      });

       test('returns false for a point not on the plane', () {
        expect(square.containsPoint(Vector3(0.5, 0.5, 1)), isFalse);
      });
    });

    group('rayIntersect', () {
      final square = Polyline.fromVector2(
          [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]);

      test('returns intersection point for a hitting ray', () {
        final ray = Ray.originDirection(Vector3(0.5, 0.5, -1), Vector3(0, 0, 1));
        final intersection = square.rayIntersect(ray);
        expect(intersection, isNotNull);
        expect(intersection!.x, closeTo(0.5, 1e-6));
        expect(intersection.y, closeTo(0.5, 1e-6));
        expect(intersection.z, closeTo(0, 1e-6));
      });

      test('returns null for a ray that misses the polygon', () {
        final ray = Ray.originDirection(Vector3(2, 2, -1), Vector3(0, 0, 1));
        expect(square.rayIntersect(ray), isNull);
      });

      test('returns null for a ray parallel to the plane', () {
        final ray = Ray.originDirection(Vector3(0.5, 0.5, 1), Vector3(1, 0, 0));
        expect(square.rayIntersect(ray), isNull);
      });

      test('returns null for a ray intersecting behind the origin', () {
        final ray = Ray.originDirection(Vector3(0.5, 0.5, 1), Vector3(0, 0, 1));
        expect(square.rayIntersect(ray), isNull);
      });
    });

    group('transform', () {
      test('transforms vertices correctly', () {
        final line = Polyline.fromVector2([Vector2(1, 0), Vector2(1, 1)]);
        final origin = Vector3(5, 0, 0);
        final xAxis = Vector3(0, 1, 0); // Swap X and Y
        final yAxis = Vector3(1, 0, 0);

        final transformed = line.transform(origin, xAxis, yAxis);

        // Original (1,0,0) becomes origin + 1*xAxis + 0*yAxis = (5,1,0)
        expect(transformed.getVector3(0), Vector3(5, 1, 0));
        // Original (1,1,0) becomes origin + 1*xAxis + 1*yAxis = (6,1,0)
        expect(transformed.getVector3(1), Vector3(6, 1, 0));
      });
    });

    group('getBounds2D', () {
      test('calculates the correct 2D bounding box', () {
        final poly = Polyline.fromVector2(
            [Vector2(-1, -2), Vector2(3, -1), Vector2(2, 4)]);
        final bounds = poly.getBounds2D();
        expect(bounds.min.x, -1);
        expect(bounds.min.y, -2);
        expect(bounds.max.x, 3);
        expect(bounds.max.y, 4);
      });
    });

    group('Equality', () {
      test('two polylines with the same vertices are equal', () {
        final p1 = Polyline.fromVector2([Vector2(0, 0), Vector2(1, 1)]);
        final p2 = Polyline.fromVector2([Vector2(0, 0), Vector2(1, 1)]);
        expect(p1, equals(p2));
        expect(p1.hashCode, equals(p2.hashCode));
      });

      test('two polylines with different vertices are not equal', () {
        final p1 = Polyline.fromVector2([Vector2(0, 0), Vector2(1, 1)]);
        final p2 = Polyline.fromVector2([Vector2(0, 0), Vector2(2, 2)]);
        expect(p1, isNot(equals(p2)));
      });
    });
  });
}
