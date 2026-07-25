import 'dart:typed_data';
import 'dart:ui';
import 'package:vector_math/vector_math.dart';

/// A utility class for filling a [Float32Array] with vertex data.

/// Deprecated, in favor of [VboFiller]
class Float32ArrayFiller {
  /// The underlying [Float32Array] that is being filled.
  Float32List array;

  int _currentPosition = 0;

  /// The current index in the [array] where the next data will be written.
  int get currentPosition => _currentPosition;

  /// Creates a [Float32ArrayFiller] that wraps the given [array].
  Float32ArrayFiller(this.array);

  /// Checks if there is enough space in the array for the next write.
  /// Throws a [RangeError] if there is not enough space.
  void _checkSpace(int requiredSpace) {
    if (_currentPosition > array.length - requiredSpace) {
      throw RangeError(
          'Not enough space in the Float32Array. Required: $requiredSpace, Available: ${array.length - _currentPosition}');
    }
  }

  /// Adds a [Vector3] to the array.
  void addV3(Vector3 vec) {
    _checkSpace(3);
    array[_currentPosition++] = vec.x;
    array[_currentPosition++] = vec.y;
    array[_currentPosition++] = vec.z;
  }

  /// Adds a [Color] to the array as four float components (R, G, B, A).
  ///
  /// Note: This assumes the [Color] object has `r`, `g`, `b`, and `a`
  /// properties that return float values, which is not standard for `dart:ui.Color`.
  /// A custom extension on [Color] may be in use.
  void addC4(Color color) {
    _checkSpace(4);
    array[_currentPosition++] = color.r;
    array[_currentPosition++] = color.g;
    array[_currentPosition++] = color.b;
    array[_currentPosition++] = color.a;
  }

  /// Adds a [Vector3] for position and a [Color] to the array.
  void addV3C4(Vector3 vec, Color color) {
    addV3(vec);
    addC4(color);
  }

  /// Adds a [Vector2] to the array.
  void addV2(Vector2 vec) {
    _checkSpace(2);
    array[_currentPosition++] = vec.x;
    array[_currentPosition++] = vec.y;
  }

  /// Adds a [Vector3] for position and a [Vector2] for texture coordinates.
  void addV3V2(Vector3 v3, Vector2 v2) {
    addV3(v3);
    addV2(v2);
  }

  /// Adds a [Vector3] for position, a [Vector2] for texture coordinates, and a [Vector3] for the normal.
  void addV3T2N3(Vector3 v, Vector2 tc, Vector3 n) {
    addV3(v);
    addV3(n);
    addV2(tc);
  }

  /// Adds a [Vector3] for position, a [Vector2] for texture coordinates, a [Vector3] for the normal and a Color for the color.
  void addV3T2N3C4(Vector3 v, Vector2 tc, Vector3 n,Color c) {
    addV3(v);
    addV3(n);
    addV2(tc);
    addC4(c);
  }

  /// Adds a textured quad to the array using two triangles.
  ///
  /// The quad's vertex positions are defined by [q], and the texture coordinates
  /// are derived from the rectangle [tr].
  void addTexturedQuad(Quad q, Rect tr) {
    Vector2 tTlc = Vector2(tr.left, tr.top);
    Vector2 tTrc = Vector2(tr.right, tr.top);
    Vector2 tBlc = Vector2(tr.left, tr.bottom);
    Vector2 tBrc = Vector2(tr.right, tr.bottom);

    // First triangle: bottom-left, bottom-right, top-right
    addV3V2(q.point0, tBlc);
    addV3V2(q.point1, tBrc);
    addV3V2(q.point2, tTrc);

    // Second triangle: bottom-left, top-right, top-left
    addV3V2(q.point0, tBlc);
    addV3V2(q.point2, tTrc);
    addV3V2(q.point3, tTlc);
  }
}
