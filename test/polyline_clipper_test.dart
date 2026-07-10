import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:fsk/fsk.dart';

/// Helper to compare two polylines for equality within a tolerance.
bool _polylinesAreEqual(Polyline? a, Polyline? b, {double epsilon = 1e-6}) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;

  final double epsilonSq = epsilon * epsilon;

  // Find the starting vertex in 'b' that matches the first vertex of 'a'
  int? bStartIndex;
  for(int i = 0; i < b.length; i++) {
    if((a.getVector3(0) - b.getVector3(i)).length2 < epsilonSq) {
      bStartIndex = i;
      break;
    }
  }

  if (bStartIndex == null) return false; // No matching start vertex found

  // Compare vertices in order, allowing for cyclic shift
  for (int i = 0; i < a.length; i++) {
    final bIndex = (bStartIndex + i) % b.length;
    if ((a.getVector3(i) - b.getVector3(bIndex)).length2 > epsilonSq) {
      return false;
    }
  }
  return true;
}

void main() {
  group('PolylineClipper', () {
    // Define a standard clipper for a 100x100 box with the bottom-left at the origin.
    final clipper = PolylineClipper(left:0, bottom:0, right:100, top:100);

    test('a polyline fully inside the clip rect remains unchanged', () {
      final insideSquare = Polyline.fromVector2([
        Vector2(25, 25),
        Vector2(75, 25),
        Vector2(75, 75),
        Vector2(25, 75),
      ]);

      final result = clipper.clip(insideSquare);

      expect(result, isNotNull);
      expect(_polylinesAreEqual(result, insideSquare), isTrue);
    });

    test('a polyline fully outside the clip rect returns null', () {
      final outsideSquare = Polyline.fromVector2([
        Vector2(125, 125),
        Vector2(175, 125),
        Vector2(175, 175),
        Vector2(125, 175),
      ]);

      final result = clipper.clip(outsideSquare);

      expect(result, isNull);
    });

    test('a simple overlapping square is clipped correctly', () {
      final overlappingSquare = Polyline.fromVector2([
        Vector2(50, 50),
        Vector2(150, 50),
        Vector2(150, 150),
        Vector2(50, 150),
      ]);

      final result = clipper.clip(overlappingSquare);

      final expected = Polyline.fromVector2([
        Vector2(100, 50),
        Vector2(100, 100),
        Vector2(50, 100),
        Vector2(50, 50),
      ]);

      expect(result, isNotNull);
      expect(_polylinesAreEqual(result, expected), isTrue);
    });

    test('a triangle crossing a corner is clipped correctly', () {
      final triangle = Polyline.fromVector2([
        Vector2(-50, 50), // Outside
        Vector2(50, -50),  // Outside
        Vector2(50, 50),   // Inside
      ]);

      final result = clipper.clip(triangle);

      final expected = Polyline.fromVector2([
        Vector2(50, 0),
        Vector2(50, 50),
        Vector2(0, 50),
        Vector2(0, 0),
      ]);

      expect(result, isNotNull);
      expect(_polylinesAreEqual(result, expected), isTrue);
    });

    test('a polyline with vertices exactly on the boundary is handled', () {
      final boundarySquare = Polyline.fromVector2([
        Vector2(0, 0),
        Vector2(100, 0),
        Vector2(100, 100),
        Vector2(0, 100),
      ]);

      final result = clipper.clip(boundarySquare);

      expect(result, isNotNull);
      expect(_polylinesAreEqual(result, boundarySquare), isTrue);
    });

    test('a polyline with fewer than 3 vertices returns null', () {
      final line = Polyline.fromVector2([Vector2(10, 10), Vector2(90, 90)]);
      final result = clipper.clip(line);
      expect(result, isNull);
    });

    test('a polyline that becomes degenerate after clipping returns null', () {
      // This triangle has two vertices on the boundary and one outside.
      // Clipping it results in a single line segment from (10,0) to (90,0),
      // which is degenerate and should be culled.
      final triangle = Polyline.fromVector2([
        Vector2(10, 0),
        Vector2(90, 0),
        Vector2(50, -10),
      ]);

      final result = clipper.clip(triangle);
      
      expect(result, isNull);
    });

    test('clipping does not create duplicate vertices from shared corners', () {
       final overlappingSquare = Polyline.fromVector2([
        Vector2(50, 50),
        Vector2(150, 50),
        Vector2(150, 150),
        Vector2(50, 150),
      ]);

      final result = clipper.clip(overlappingSquare);
      expect(result, isNotNull);

      // The Sutherland-Hodgman algorithm can produce duplicate vertices.
      // The final result should be cleaned up to have only unique vertices.
      expect(result!.length, 4, reason: "The clipped polygon should have 4 unique vertices");
    });

  });
}
