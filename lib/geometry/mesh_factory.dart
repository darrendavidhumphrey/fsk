import 'dart:typed_data';
import 'dart:ui';
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart';

/// A utility class with static methods to create complex [TriangleMesh] objects
/// or generate [Float32List] vertex data.
class MeshFactory {
  // Private constructor to prevent instantiation of this utility class.
  MeshFactory._();

  /////////////////////////////////////////////////////////////////////////////
  // Public API Methods
  /////////////////////////////////////////////////////////////////////////////

  // --- FskMesh Creation ---

  /// Creates an [FskMesh] from a solid's faces.
  static FskMesh meshFromSolidFaces(String id, FskSceneBase scene, List<Polyline> faces,
      {FskShaderMaterial? material}) {
    return _createMesh(id, scene, faces, (filler, face) {
      _addTexturedTriFan(filler, face, true);
    }, material: material);
  }

  /// Creates an [FskMesh] by tessellating a list of [outlines] with texture coordinates.
  static FskMesh meshFromOutlines(String id, FskSceneBase scene, List<Polyline> outlines,
      bool generateNormals, {FskShaderMaterial? material}) {
    return _createMesh(id, scene, outlines, (filler, outline) {
      _addTexturedTriFan(filler, outline, generateNormals);
    }, material: material);
  }

  /// Creates an [FskMesh] by tessellating a list of [outlines] with a solid [color].
  static FskMesh meshFromColorOutlines(String id, FskSceneBase scene,
      List<Polyline> outlines, Color color, {FskShaderMaterial? material}) {
    return _createMesh(id, scene, outlines, (filler, outline) {
      _addTexturedTriFan(filler, outline, true, color: color);
    }, material: material ?? FskShaderMaterial.flat);
  }

  /// Creates an [FskMesh] that forms a thick, mitered outline around a [quad].
  static FskMesh meshFromQuadOutline(
      {required String id, required FskSceneBase parentScene, required Quad quad, required double thickness, required Color color,
      FskShaderMaterial? material}) {
    final outlines = createThickOutline3DFromQuad(quad, thickness);
    return meshFromColorOutlines(id, parentScene, outlines, color, material: material);
  }

  /// Creates a new [FskMesh] by extruding a list of [outlines] by a [depth] vector.
  static FskMesh extrudeToMesh(String id, FskSceneBase scene, List<Polyline> outlines, Vector3 depth,
      {FskShaderMaterial? material}) {
    final mesh = FskMesh(id, scene, shaderMaterial: material);
    final vertices = verticesFromExtrusion(outlines, depth);
    if (vertices.isNotEmpty) {
      mesh.vertices = vertices;
      mesh.uploadToGpu();
      mesh.renderer.addFskSubMesh(FskSubMesh(count: vertices.length ~/ FskVertexBuffer.componentCount, offset: 0));
      mesh.renderer.finalizeData();
    }
    return mesh;
  }

  /// Creates an [FskMesh] from a CPU-side [TriangleMesh].
  static FskMesh fromTriangleMesh(String id, FskSceneBase scene, TriangleMesh triangleMesh,
      {FskShaderMaterial? material, Color color = const Color(0xFFFFFFFF)}) {
    final mesh = FskMesh(id, scene, shaderMaterial: material);
    final int vertexCount = triangleMesh.triangleCount * 3;
    if (vertexCount > 0) {
      final vertices = Float32List(vertexCount * FskVertexBuffer.componentCount);
      final filler = VboFiller(vertices);
      final rawData = triangleMesh.vertexData;

      for (int i = 0; i < vertexCount; i++) {
        int baseIndex = i * TriangleMesh.componentCount;
        // P(3), T(2), N(3)
        Vector3 pos = Vector3(rawData[baseIndex], rawData[baseIndex + 1], rawData[baseIndex + 2]);
        Vector2 tex = Vector2(rawData[baseIndex + 3], rawData[baseIndex + 4]);
        Vector3 normal = Vector3(rawData[baseIndex + 5], rawData[baseIndex + 6], rawData[baseIndex + 7]);

        filler.addV3T2N3C4(pos, tex, normal, color);
      }
      mesh.vertices = vertices;
      mesh.uploadToGpu();
      mesh.renderer.addFskSubMesh(FskSubMesh(count: vertexCount, offset: 0));
      mesh.renderer.finalizeData();
    }

    return mesh;
  }

  // --- Vertex Data (Float32List) Generation ---

  /// Generates vertex data from a list of [faces].
  static Float32List verticesFromSolidFaces(List<Polyline> faces) {
    return _tessellate(faces, (filler, face) {
      _addTexturedTriFan(filler, face, true);
    });
  }

  /// Generates vertex data by tessellating a list of [outlines] with a solid [color].
  static Float32List verticesFromColorOutlines(List<Polyline> outlines, Color color) {
    return _tessellate(outlines, (filler, outline) {
      _addTexturedTriFan(filler, outline, true, color: color);
    });
  }

  /// Generates vertex data by tessellating a list of [outlines] with texture coordinates.
  static Float32List verticesFromOutlines(List<Polyline> outlines, bool generateNormals) {
    return _tessellate(outlines, (filler, outline) {
      _addTexturedTriFan(filler, outline, generateNormals);
    });
  }

  /// Generates vertex data by extruding a list of [outlines] by a [depth] vector.
  static Float32List verticesFromExtrusion(List<Polyline> outlines, Vector3 depth) {
    if (outlines.isEmpty) return Float32List(0);

    // Calculate total triangles needed for top/bottom caps and side walls.
    int topCount = 0;
    for (var outline in outlines) {
      if (outline.length > 2) {
        topCount += (outline.length - 2);
      }
    }

    int sideCount = 0;
    for (var outline in outlines) {
      sideCount += (outline.length) * 2;
    }

    int extrudedTriangleCount = topCount * 2 + sideCount;
    if (extrudedTriangleCount == 0) return Float32List(0);

    int vertexCount = extrudedTriangleCount * 3;
    final vertices = Float32List(vertexCount * FskVertexBuffer.componentCount);
    final filler = VboFiller(vertices);

    // Add the top faces.
    for (var outline in outlines) {
      if (outline.planeIsValid && outline.length > 2) {
        _addTexturedTriFan(filler, outline, true);
      }
    }

    // Add the bottom faces.
    for (var outline in outlines) {
      if (outline.planeIsValid && outline.length > 2) {
        Vector3 bottomNormal = -outline.normal!;
        _addReverseTexturedTriFan(filler, outline, bottomNormal, depth);
      }
    }

    // Add the side walls.
    for (var outline in outlines) {
      for (int i = 0; i < outline.length; i++) {
        _makeSideFromEdgeVertices(filler, outline, i, depth);
      }
    }

    return vertices;
  }

  // --- TriangleMesh (CPU) Creation ---

  /// Creates a [TriangleMesh] by tessellating a list of [faces].
  ///
  /// This is useful for generating geometry for CPU-side operations like picking
  /// or physics calculations.
  static TriangleMesh fromFaces(List<Polyline> faces) {
    // Safely calculate the exact number of triangles needed.
    int triangleCount = 0;
    for (var face in faces) {
      // A convex polygon with N vertices tessellates into N-2 triangles.
      if (face.length > 2) {
        triangleCount += face.length - 2;
      }
    }

    if (triangleCount == 0) {
      return TriangleMesh.empty();
    }

    final mesh = TriangleMesh(triangleCount);

    int currentTriangle = 0;
    for (var face in faces) {
      currentTriangle = _addOutlineAsTriFan(mesh, face, currentTriangle);
    }

    return mesh;
  }

  /// Creates a new [TriangleMesh] by extruding a list of [outlines] by a [depth] vector.
  /// This generates top, bottom, and side faces to create a closed 3D shape.
  static TriangleMesh extrude(List<Polyline> outlines, Vector3 depth) {
    if (outlines.isEmpty) {
      return TriangleMesh.empty();
    }

    // Calculate total triangles needed for top/bottom caps and side walls.
    int topCount = 0;
    for (var outline in outlines) {
      if (outline.length > 2) {
        topCount += (outline.length - 2);
      }
    }

    int sideCount = 0;
    for (var outline in outlines) {
      sideCount += (outline.length) * 2; // Each edge of the outline becomes 2 triangles.
    }

    int extrudedTriangleCount = topCount * 2 + sideCount;
    if (extrudedTriangleCount == 0) {
      return TriangleMesh.empty();
    }

    TriangleMesh result = TriangleMesh(extrudedTriangleCount);
    int currentTriangle = 0;

    // Add the top faces.
    for (var outline in outlines) {
      if (outline.planeIsValid) {
        currentTriangle =
            _addOutlineAsTriFan(result, outline, currentTriangle);
      }
    }

    // Add the bottom faces (reversed winding order).
    for (var outline in outlines) {
      if (outline.planeIsValid) {
        Vector3 bottomNormal = -outline.normal!;
        currentTriangle = _addOutlineAsReverseTriFan(
            result, outline, bottomNormal, currentTriangle, depth);
      }
    }

    // Add the side walls.
    for (var outline in outlines) {
      for (int i = 0; i < outline.length; i++) {
        currentTriangle =
            _makeSideFromEdge(result, outline, i, currentTriangle, depth);
      }
    }

    return result;
  }

  /////////////////////////////////////////////////////////////////////////////
  // Internal Helper Methods
  /////////////////////////////////////////////////////////////////////////////

  /// Generic helper to create an [FskMesh] from a list of outlines.
  static FskMesh _createMesh(
      String id,
      FskSceneBase scene,
      List<Polyline> outlines,
      void Function(VboFiller, Polyline) addFunction, {
        FskShaderMaterial? material,
      }) {
    int triangleCount = 0;
    for (var outline in outlines) {
      if (outline.length > 2) {
        triangleCount += (outline.length - 2);
      }
    }

    final mesh = FskMesh(id, scene, shaderMaterial: material);
    int newVertexCount = triangleCount * 3;
    if (newVertexCount > 0) {
      final vertices = Float32List(newVertexCount * FskVertexBuffer.componentCount);
      final filler = VboFiller(vertices);
      for (var outline in outlines) {
        if (outline.length > 2) {
          addFunction(filler, outline);
        }
      }
      mesh.vertices = vertices;
      mesh.uploadToGpu();
      mesh.renderer.addFskSubMesh(FskSubMesh(count: newVertexCount, offset: 0));
      mesh.renderer.finalizeData();
    }

    return mesh;
  }

  /// Generic helper to tessellate a list of outlines into a Float32List.
  static Float32List _tessellate(List<Polyline> outlines,
      void Function(VboFiller, Polyline) addFunction) {
    int triangleCount = 0;
    for (var outline in outlines) {
      if (outline.length > 2) {
        triangleCount += (outline.length - 2);
      }
    }

    int newVertexCount = triangleCount * 3;
    final vertices = Float32List(newVertexCount * FskVertexBuffer.componentCount);

    if (newVertexCount > 0) {
      final filler = VboFiller(vertices);
      for (var outline in outlines) {
        if (outline.length > 2) {
          addFunction(filler, outline);
        }
      }
    }
    return vertices;
  }

  /// Private helper to add a textured triangle fan for a single outline to a Float32List via VboFiller.
  static void _addTexturedTriFan(
      VboFiller filler, Polyline outline, bool generateNormals,{Color? color}) {
    int numTris = outline.length - 2;
    Vector3 v0 = outline.getVector3(0);
    Vector3 normal = Vector3.zero();

    if (outline.planeIsValid) {
      normal = outline.normal!;
    }

    final bounds = outline.getBounds2D();
    double w = bounds.max.x - bounds.min.x;
    double h = bounds.max.y - bounds.min.y;
    double x = bounds.min.x;
    double y = bounds.min.y;

    for (int j = 0; j < numTris; j++) {
      Vector3 v1 = outline.getVector3(j + 1);
      Vector3 v2 = outline.getVector3(j + 2);

      List<Vector2> texCoord = computeTexCoords(v0, v1, v2, x, y, w, h);

      if (generateNormals) {
        if (color != null) {
          filler.addV3T2N3C4(v0, texCoord[0], normal,color);
          filler.addV3T2N3C4(v1, texCoord[1], normal,color);
          filler.addV3T2N3C4(v2, texCoord[2], normal,color);
        } else {
          filler.addV3T2N3(v0, texCoord[0], normal);
          filler.addV3T2N3(v1, texCoord[1], normal);
          filler.addV3T2N3(v2, texCoord[2], normal);
        }
      } else {
        filler.addV3T2(v0, texCoord[0]);
        filler.addV3T2(v1, texCoord[1]);
        filler.addV3T2(v2, texCoord[2]);
      }
    }
  }

  /// Private helper to add a reversed textured triangle fan for the bottom cap to a Float32List via VboFiller.
  static void _addReverseTexturedTriFan(VboFiller filler, Polyline outline, Vector3 normal, Vector3 depth) {
    int numTris = outline.length - 2;

    final bounds = outline.getBounds2D();
    double w = bounds.max.x - bounds.min.x;
    double h = bounds.max.y - bounds.min.y;
    double x = bounds.min.x;
    double y = bounds.min.y;

    Vector3 v0 = outline.getVector3(0) + depth;
    for (int j = 0; j < numTris; j++) {
      Vector3 v1 = outline.getVector3(j + 2) + depth;
      Vector3 v2 = outline.getVector3(j + 1) + depth;

      List<Vector2> texCoord = computeTexCoords(v2, v1, v0, x, y, w, h);

      filler.addV3T2N3(v2, texCoord[0], normal);
      filler.addV3T2N3(v1, texCoord[1], normal);
      filler.addV3T2N3(v0, texCoord[2], normal);
    }
  }

  /// Private helper to add side wall triangles to a Float32List via VboFiller.
  static void _makeSideFromEdgeVertices(VboFiller filler, Polyline outline, int index, Vector3 depth) {
    Vector3 p1 = outline.getVector3(index % outline.length);
    Vector3 p2 = outline.getVector3((index + 1) % outline.length);
    Vector3 normal = (p2 - p1).cross(depth).normalized();

    Vector3 p1z = p1 + depth;
    Vector3 p2z = p2 + depth;

    // TODO: Calculate correct texture coordinates for sides.
    filler.addV3T2N3(p1, Vector2.zero(), normal);
    filler.addV3T2N3(p2, Vector2(1, 0), normal);
    filler.addV3T2N3(p2z, Vector2(1, 1), normal);

    filler.addV3T2N3(p1, Vector2.zero(), normal);
    filler.addV3T2N3(p2z, Vector2(1, 1), normal);
    filler.addV3T2N3(p1z, Vector2(0, 1), normal);
  }

  /// Helper to generate the top cap of an extruded mesh for a CPU-side [TriangleMesh].
  static int _addOutlineAsTriFan(
      TriangleMesh mesh, Polyline outline, int currentTriangle) {
    if (!outline.planeIsValid) return currentTriangle;
    int numTris = outline.length - 2;

    final bounds = outline.getBounds2D();
    double w = bounds.max.x - bounds.min.x;
    double h = bounds.max.y - bounds.min.y;
    double x = bounds.min.x;
    double y = bounds.min.y;

    Vector3 v0 = outline.getVector3(0);
    for (int i = 0; i < numTris; i++) {
      Vector3 v1 = outline.getVector3(i + 1);
      Vector3 v2 = outline.getVector3(i + 2);

      List<Vector2> texCoord = computeTexCoords(v0, v1, v2, x, y, w, h);

      currentTriangle = mesh.addTriangle(
          v0, v1, v2, outline.normal!, texCoord, currentTriangle);
    }
    return currentTriangle;
  }

  /// Helper to generate the bottom cap of an extruded mesh with reversed winding for a CPU-side [TriangleMesh].
  static int _addOutlineAsReverseTriFan(TriangleMesh mesh, Polyline outline,
      Vector3 normal, int currentTriangle, Vector3 depth) {
    if (!outline.planeIsValid) return currentTriangle;
    int numTris = outline.length - 2;

    final bounds = outline.getBounds2D();
    double w = bounds.max.x - bounds.min.x;
    double h = bounds.max.y - bounds.min.y;
    double x = bounds.min.x;
    double y = bounds.min.y;

    Vector3 v0 = outline.getVector3(0) + depth;
    for (int i = 0; i < numTris; i++) {
      Vector3 v1 = outline.getVector3(i + 2) + depth;
      Vector3 v2 = outline.getVector3(i + 1) + depth;

      List<Vector2> texCoord = computeTexCoords(v2, v1, v0, x, y, w, h);

      currentTriangle =
          mesh.addTriangle(v2, v1, v0, normal, texCoord, currentTriangle);
    }
    return currentTriangle;
  }

  /// Helper to generate the two triangles that form a side wall from one edge of an outline for a CPU-side [TriangleMesh].
  static int _makeSideFromEdge(TriangleMesh mesh, Polyline outline, int index,
      int currentTriangle, Vector3 depth) {
    Vector3 p1 = outline.getVector3(index % outline.length);
    Vector3 p2 = outline.getVector3((index + 1) % outline.length);
    Vector3 normal = (p2 - p1).cross(depth).normalized();

    Vector3 p1z = p1 + depth;
    Vector3 p2z = p2 + depth;

    // TODO: Calculate correct texture coordinates for sides.
    List<Vector2> texCoord = [Vector2.zero(), Vector2(1, 0), Vector2(1, 1)];
    currentTriangle =
        mesh.addTriangle(p1, p2, p2z, normal, texCoord, currentTriangle);

    texCoord = [Vector2.zero(), Vector2(1, 1), Vector2(0, 1)];
    currentTriangle =
        mesh.addTriangle(p1, p2z, p1z, normal, texCoord, currentTriangle);

    return currentTriangle;
  }
}
