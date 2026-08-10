import 'dart:typed_data';
import 'dart:ui';
import 'package:vector_math/vector_math.dart' as vm;

/// A utility class for filling a vertex buffer list with data.
class VboFiller {
  /// The underlying [Float32List] that is being filled.
  final Float32List list;

  int _currentPosition = 0;

  /// The current index in the [list] where the next data will be written.
  int get currentPosition => _currentPosition;

  VboFiller(this.list);

  /// Checks if there is enough space in the array for the next write.
  /// Throws a [RangeError] if there is not enough space.
  void _checkStrideSpace() {
    if (_currentPosition > list.length - 12) {
      throw RangeError(
          'Not enough space in the Float32Array for a full vertex stride. '
              'Required: 12 elements, Available: ${list.length - _currentPosition}');
    }
  }


  /// Adds a [Vector3] to the array.
  void _addV3(vm.Vector3 vec) {
    list[_currentPosition++] = vec.x;
    list[_currentPosition++] = vec.y;
    list[_currentPosition++] = vec.z;
  }

  void _addC4(Color color) {
    list[_currentPosition++] = color.r;
    list[_currentPosition++] = color.g;
    list[_currentPosition++] = color.b;
    list[_currentPosition++] = color.a;
  }

  /// Adds a [Vector3] for position and a [Color] to the array.
  void addV3C4(vm.Vector3 vec, Color color) {
    _checkStrideSpace();
   _addV3(vec);
   _currentPosition += 2; // SKip T2
   _currentPosition += 3; // Skip N3
   _addC4(color);
  }

  /// Adds a [Vector2] to the array.
  void _addT2(vm.Vector2 vec) {
    list[_currentPosition++] = vec.x;
    list[_currentPosition++] = vec.y;
  }

  /// Adds a [Vector3] for position and a [Vector2] for texture coordinates.
  void addV3T2(vm.Vector3 v3, vm.Vector2 t2) {
    _checkStrideSpace();
    _addV3(v3);
    _addT2(t2);

    // Skip normal and color
    _currentPosition += 7;
  }

  /// Adds a [Vector3] for position, a [Vector2] for texture coordinates, and a [Vector3] for the normal.
  void addV3T2N3(vm.Vector3 v, vm.Vector2 tc, vm.Vector3 n) {
    _checkStrideSpace();
    _addV3(v);
    _addT2(tc);
    _addV3(n);
    // Skip color
    _currentPosition += 4;
  }

  /// Adds a [Vector3] for position, a [Vector2] for texture coordinates, a [Vector3] for the normal and a Color for the color.
  void addV3T2N3C4(vm.Vector3 v, vm.Vector2 tc, vm.Vector3 n,Color c) {
    _checkStrideSpace();
    _addV3(v);
    _addT2(tc);
    _addV3(n);
    _addC4(c);
  }

  /// Adds a textured quad to the array using two triangles.
  /// The quad's vertex positions are defined by [q], and the texture coordinates
  /// are derived from the rectangle [tr].
  void addTexturedQuad(vm.Quad q, Rect tr) {
    vm.Vector2 tTlc = vm.Vector2(tr.left, tr.top);
    vm.Vector2 tTrc = vm.Vector2(tr.right, tr.top);
    vm.Vector2 tBlc = vm.Vector2(tr.left, tr.bottom);
    vm.Vector2 tBrc = vm.Vector2(tr.right, tr.bottom);

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

    vm.Quad q = vm.Quad.points(
      vm.Vector3(r.left, r.bottom, z),
      vm.Vector3(r.right, r.bottom, z),
      vm.Vector3(r.right, r.top, z),
      vm.Vector3(r.left, r.top, z),
    );

    addTexturedQuad(q, tr);
  }

  // Makes ONE quad only, setting the vbo size to 6 vertices
  static Float32List makeTexturedUnitQuad(Rect r, double z) {
    final list = Float32List(6 * 12);
    var filler = VboFiller(list);
    filler._addTexturedUnitQuad(r,z);
    return list;
  }

  // Makes ONE quad only, setting the vbo size to 6 vertices with texture
  //   /// coordinates from [0, 0] to [1, 1].
  static Float32List makeTexturedQuad(vm.Quad q, Rect tr) {
    final list = Float32List(6 * 12);
    var filler = VboFiller(list);
    filler.addTexturedQuad(q,tr);
    return list;
  }

  // Appends a list of quads to a VBO
  static Float32List verticesFromTexturedQuads(List<vm.Quad> quads, List<Rect> tr) {
    assert (quads.length == tr.length);
    final list = Float32List(quads.length * 6 * 12);
    var filler = VboFiller(list);

    for (var i = 0; i < quads.length; i++) {
      filler.addTexturedQuad(quads[i], tr[i]);
    }
    return list;
  }

  /// Generates vertex data from unrolled quads (5 components: XYZUV).
  static Float32List verticesFromUnrolledQuads(int numQuads, Float32List xyzuv) {
    const int arrayStride = 5;
    if (numQuads == 0 || xyzuv.isEmpty || xyzuv.length != arrayStride * numQuads * 4) {
      return Float32List(0);
    }

    final int numQuadVerts = 6 * numQuads;
    final list = Float32List(numQuadVerts * 12);
    final filler = VboFiller(list);

    for (int i = 0; i < numQuads; i++) {
      int v0Index = i * arrayStride * 4;
      int v1Index = v0Index + arrayStride;
      int v2Index = v1Index + arrayStride;
      int v3Index = v2Index + arrayStride;

      int blIndex = v0Index + 3;
      int brIndex = v1Index + 3;
      int trIndex = v2Index + 3;
      int tlIndex = v3Index + 3;

      // First triangle: bottom-left, bottom-right, top-right
      filler.addV3T2(
        vm.Vector3(xyzuv[v0Index], xyzuv[v0Index + 1], xyzuv[v0Index + 2]),
        vm.Vector2(xyzuv[blIndex], xyzuv[blIndex + 1]),
      );
      filler.addV3T2(
        vm.Vector3(xyzuv[v1Index], xyzuv[v1Index + 1], xyzuv[v1Index + 2]),
        vm.Vector2(xyzuv[brIndex], xyzuv[brIndex + 1]),
      );
      filler.addV3T2(
        vm.Vector3(xyzuv[v2Index], xyzuv[v2Index + 1], xyzuv[v2Index + 2]),
        vm.Vector2(xyzuv[trIndex], xyzuv[trIndex + 1]),
      );

      // Second triangle: bottom-left, top-right, top-left
      filler.addV3T2(
        vm.Vector3(xyzuv[v0Index], xyzuv[v0Index + 1], xyzuv[v0Index + 2]),
        vm.Vector2(xyzuv[blIndex], xyzuv[blIndex + 1]),
      );
      filler.addV3T2(
        vm.Vector3(xyzuv[v2Index], xyzuv[v2Index + 1], xyzuv[v2Index + 2]),
        vm.Vector2(xyzuv[trIndex], xyzuv[trIndex + 1]),
      );
      filler.addV3T2(
        vm.Vector3(xyzuv[v3Index], xyzuv[v3Index + 1], xyzuv[v3Index + 2]),
        vm.Vector2(xyzuv[tlIndex], xyzuv[tlIndex + 1]),
      );
    }
    return list;
  }
}
