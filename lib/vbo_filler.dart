import 'dart:typed_data';
import 'dart:ui';
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart';

/// A utility class for filling a [VBO] with vertex data.
class VboFiller {
  /// The underlying [Float32List] that is being filled.
  Float32List array;
  VertexBuffer buffer;

  int _currentPosition = 0;

  /// The current index in the [array] where the next data will be written.
  int get currentPosition => _currentPosition;

  VboFiller(this.array,this.buffer);

  /// Checks if there is enough space in the array for the next write.
  /// Throws a [RangeError] if there is not enough space.
  void _checkSpace(int requiredSpace) {
    if (_currentPosition > array.length - requiredSpace) {
      throw RangeError(
          'Not enough space in the Float32Array. Required: $requiredSpace, Available: ${array.length - _currentPosition}');
    }
  }


  /// Adds a [Vector3] to the array.
  void _addV3(Vector3 vec) {
    _checkSpace(3);

    array[_currentPosition++] = vec.x;
    array[_currentPosition++] = vec.y;
    array[_currentPosition++] = vec.z;
  }

  void _addC4(Color color) {
    _checkSpace(4);
    array[_currentPosition++] = color.r;
    array[_currentPosition++] = color.g;
    array[_currentPosition++] = color.b;
    array[_currentPosition++] = color.a;
  }

  /// Adds a [Vector3] for position and a [Color] to the array.
  void addV3C4(Vector3 vec, Color color) {
   _addV3(vec);
   _addC4(color);
  }

  /// Adds a [Vector2] to the array.
  void _addT2(Vector2 vec) {
    _checkSpace(2);
    array[_currentPosition++] = vec.x;
    array[_currentPosition++] = vec.y;
  }

  /// Adds a [Vector3] for position and a [Vector2] for texture coordinates.
  void addV3T2(Vector3 v3, Vector2 v2) {
    _addV3(v3);
    _addT2(v2);

    // Skip normal and color
    _currentPosition += 7;
  }

  /// Adds a [Vector3] for position, a [Vector2] for texture coordinates, and a [Vector3] for the normal.
  void addV3T2N3(Vector3 v, Vector2 tc, Vector3 n) {
    _addV3(v);
    _addT2(tc);
    _addV3(n);
    // Skip color
    _currentPosition += 4;
  }

  /// Adds a [Vector3] for position, a [Vector2] for texture coordinates, a [Vector3] for the normal and a Color for the color.
  void addV3T2N3C4(Vector3 v, Vector2 tc, Vector3 n,Color c) {
    _addV3(v);
    _addT2(tc);
    _addV3(n);
    _addC4(c);
  }

  /// Adds a textured quad to the array using two triangles.
  /// The quad's vertex positions are defined by [q], and the texture coordinates
  /// are derived from the rectangle [tr].
  void _addTexturedQuad(Quad q, Rect tr) {
    Vector2 tTlc = Vector2(tr.left, tr.top);
    Vector2 tTrc = Vector2(tr.right, tr.top);
    Vector2 tBlc = Vector2(tr.left, tr.bottom);
    Vector2 tBrc = Vector2(tr.right, tr.bottom);

    // First triangle: bottom-left, bottom-right, top-right
    addV3T2(q.point0, tBlc);
    addV3T2(q.point1, tBrc);
    addV3T2(q.point2, tTrc);

    // Second triangle: bottom-left, top-right, top-left
    addV3T2(q.point0, tBlc);
    addV3T2(q.point2, tTrc);
    addV3T2(q.point3, tTlc);
  }

  /// Fills the buffer with six vertices to form a textured quad with texture
  /// coordinates from [0, 0] to [1, 1].
  void _addTexturedUnitQuad(Rect r, double z) {
    Rect tr = Rect.fromLTWH(0, 0, 1, 1);

    Quad q = Quad.points(
      Vector3(r.left, r.bottom, z),
      Vector3(r.right, r.bottom, z),
      Vector3(r.right, r.top, z),
      Vector3(r.left, r.top, z),
    );

    _addTexturedQuad(q, tr);
  }

  // Makes ONE quad only, setting the vbo size to 6 vertices
  static void makeTexturedUnitQuad(Rect r, double z,VertexBuffer vbo) {
    var filler = VboFiller(vbo.requestBuffer(6)!, vbo);
    filler._addTexturedUnitQuad(r,z);
    vbo.setActiveVertexCount(6);
  }

  // Makes ONE quad only, setting the vbo size to 6 vertices with texture
  //   /// coordinates from [0, 0] to [1, 1].
  static void makeTexturedQuad(Quad q, Rect tr,VertexBuffer vbo) {
    var filler = VboFiller(vbo.requestBuffer(6)!, vbo);
    filler._addTexturedQuad(q,tr);
    vbo.setActiveVertexCount(6);
  }

  // Appends a list of quads to a VBO
  static void addTexturedQuads(List<Quad> quads, List<Rect> tr,VertexBuffer vbo) {
    var filler = VboFiller(vbo.vertexData!, vbo);
    assert (quads.length == tr.length);

    for (var i = 0; i < quads.length; i++) {
      filler._addTexturedQuad(quads[i], tr[i]);
    }
  }
}
