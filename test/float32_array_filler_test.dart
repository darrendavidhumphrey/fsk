import 'dart:ui';

import 'package:flutter_angle/flutter_angle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsg/float32_array_filler.dart';
import 'package:fsg/native_array/index.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('Float32ArrayFiller', () {
    late Float32Array array;
    late Float32ArrayFiller filler;

    setUp(() {
      array = Float32Array(64); // A reasonably sized array for tests
      filler = Float32ArrayFiller(array);
    });

    test('addV3 should add a Vector3 to the array', () {
      final vec = Vector3(1.0, 2.0, 3.0);
      filler.addV3(vec);
      expect(filler.currentPosition, 3);
      expect(array.sublist(0, 3), equals([1.0, 2.0, 3.0]));
    });

    test('addC4 should add a Color to the array', () {
      final color = Color.from(red: 0.25, green: 0.5, blue: 0.75, alpha: 1.0);
      filler.addC4(color);
      expect(filler.currentPosition, 4);
      expect(array.sublist(0, 4), equals([0.25, 0.5, 0.75, 1.0]));
    });

    test('addV3C4 should add a Vector3 and a Color', () {
      final vec = Vector3(1.0, 2.0, 3.0);
      final color = Color.from(red: 0.25, green: 0.5, blue: 0.75, alpha: 1.0);
      filler.addV3C4(vec, color);
      expect(filler.currentPosition, 7);
      expect(array.sublist(0, 7), equals([1.0, 2.0, 3.0, 0.25, 0.5, 0.75, 1.0]));
    });

    test('addV2 should add a Vector2 to the array', () {
      final vec = Vector2(4.0, 5.0);
      filler.addV2(vec);
      expect(filler.currentPosition, 2);
      expect(array.sublist(0, 2), equals([4.0, 5.0]));
    });

    test('addV3V2 should add a Vector3 and a Vector2', () {
      final v3 = Vector3(1.0, 2.0, 3.0);
      final v2 = Vector2(4.0, 5.0);
      filler.addV3V2(v3, v2);
      expect(filler.currentPosition, 5);
      expect(array.sublist(0, 5), equals([1.0, 2.0, 3.0, 4.0, 5.0]));
    });

    test('addV3T2N3 should add position, texture, and normal vectors', () {
      final v = Vector3(1, 2, 3);
      final tc = Vector2(0.5, 0.5);
      final n = Vector3(0, 1, 0);
      filler.addV3T2N3(v, tc, n);
      expect(filler.currentPosition, 8);
      expect(array.sublist(0, 8), equals([1, 2, 3, 0.5, 0.5, 0, 1, 0]));
    });

    test('addTriangleWithColor should add three vertices with the same color', () {
      final v1 = Vector3(1, 1, 0);
      final v2 = Vector3(2, 1, 0);
      final v3 = Vector3(1, 2, 0);
      final color = Color.from(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0);

      filler.addTriangleWithColor(v1, v2, v3, color);

      expect(filler.currentPosition, 21); // 3 vertices * (3 floats for pos + 4 floats for color)

      // Check vertex 1
      expect(array.sublist(0, 7), equals([1, 1, 0, 1, 0, 0, 1]));
      // Check vertex 2
      expect(array.sublist(7, 14), equals([2, 1, 0, 1, 0, 0, 1]));
      // Check vertex 3
      expect(array.sublist(14, 21), equals([1, 2, 0, 1, 0, 0, 1]));
    });

    test('addTexturedQuad should add six vertices for two triangles', () {
      final bl = Vector3(-1, -1, 0);
      final br = Vector3(1, -1, 0);
      final tr = Vector3(1, 1, 0);
      final tl = Vector3(-1, 1, 0);
      final quad = Quad.points(bl, br, tr, tl);
      final rect = Rect.fromLTWH(0, 0, 1, 1);

      filler.addTexturedQuad(quad, rect);

      expect(filler.currentPosition, 30); // 6 vertices * (3 for pos + 2 for tex)

      // Triangle 1: bl, br, tr
      expect(array.sublist(0, 5), equals([-1, -1, 0, 0, 1])); // bl
      expect(array.sublist(5, 10), equals([1, -1, 0, 1, 1])); // br
      expect(array.sublist(10, 15), equals([1, 1, 0, 1, 0])); // tr

      // Triangle 2: bl, tr, tl
      expect(array.sublist(15, 20), equals([-1, -1, 0, 0, 1])); // bl
      expect(array.sublist(20, 25), equals([1, 1, 0, 1, 0])); // tr
      expect(array.sublist(25, 30), equals([-1, 1, 0, 0, 0])); // tl
    });

    test('should throw RangeError when there is not enough space', () {
      final smallArray = Float32Array(2);
      final smallFiller = Float32ArrayFiller(smallArray);

      expect(() => smallFiller.addV3(Vector3.zero()), throwsRangeError);
    });

    test('should throw RangeError on sequential adds that overflow', () {
      final smallArray = Float32Array(5);
      final smallFiller = Float32ArrayFiller(smallArray);

      smallFiller.addV3(Vector3.zero()); // Fills 3, 2 remaining

      expect(() => smallFiller.addV3(Vector3.zero()), throwsRangeError);
    });
  });
}
