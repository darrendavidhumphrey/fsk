import 'dart:typed_data';
import 'dart:ui';
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// A utility class with static methods to create complex [TriangleMesh] objects
/// or generate [Float32List] vertex data.
class MeshFactory {
  // Private constructor to prevent instantiation of this utility class.
  MeshFactory._();

  /////////////////////////////////////////////////////////////////////////////
  // Public API Methods
  /////////////////////////////////////////////////////////////////////////////

  // --- FskMesh Creation ---

  /// Generates vertex data for a solid from its faces.
  static Float32List verticesFromSolidFaces(List<Polyline> faces) {
    int triangleCount = 0;
    for (var face in faces) {
      if (face.length > 2) {
        triangleCount += (face.length - 2);
      }
    }

    int newVertexCount = triangleCount * 3;
    final vertices =
        Float32List(newVertexCount * FskVertexBuffer.componentCount);
    final filler = VboFiller(vertices);
    for (var face in faces) {
      if (face.length > 2) {
        _addTexturedTriFan(filler, face, true);
      }
    }
    return vertices;
  }

  /// Creates an [FskMesh] from a solid's faces.
  static FskMesh meshFromSolidFaces(String id, FskSceneBase scene, List<Polyline> faces,
      {FskShaderMaterial? material}) {
    final mesh = FskMesh(id, scene, shaderMaterial: material);
    mesh.vertices = verticesFromSolidFaces(faces);
    mesh.uploadToGpu();
    mesh.renderer.addFskSubMesh(FskSubMesh(count: mesh.vertices!.length ~/ FskVertexBuffer.componentCount, offset: 0));
    mesh.renderer.finalizeData();
    return mesh;
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
      {required String id, required FskSceneBase parentScene, required vm.Quad quad, required double thickness, required Color color,
      FskShaderMaterial? material}) {
    final outlines = createThickOutline3DFromQuad(quad, thickness);
    return meshFromColorOutlines(id, parentScene, outlines, color, material: material);
  }


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
  static TriangleMesh extrude(List<Polyline> outlines, vm.Vector3 depth) {
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
        vm.Vector3 bottomNormal = -outline.normal!;
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

  /// Private helper to add a textured triangle fan for a single outline to a Float32List via VboFiller.
  static void _addTexturedTriFan(
      VboFiller filler, Polyline outline, bool generateNormals,{Color? color}) {
    int numTris = outline.length - 2;
    vm.Vector3 v0 = outline.getVector3(0);
    vm.Vector3 normal = vm.Vector3.zero();

    if (outline.planeIsValid) {
      normal = outline.normal!;
    }

    final bounds = outline.getBounds2D();
    double w = bounds.max.x - bounds.min.x;
    double h = bounds.max.y - bounds.min.y;
    double x = bounds.min.x;
    double y = bounds.min.y;

    for (int j = 0; j < numTris; j++) {
      vm.Vector3 v1 = outline.getVector3(j + 1);
      vm.Vector3 v2 = outline.getVector3(j + 2);

      List<vm.Vector2> texCoord = computeTexCoords(v0, v1, v2, x, y, w, h);

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

    vm.Vector3 v0 = outline.getVector3(0);
    for (int i = 0; i < numTris; i++) {
      vm.Vector3 v1 = outline.getVector3(i + 1);
      vm.Vector3 v2 = outline.getVector3(i + 2);

      List<vm.Vector2> texCoord = computeTexCoords(v0, v1, v2, x, y, w, h);

      currentTriangle = mesh.addTriangle(
          v0, v1, v2, outline.normal!, texCoord, currentTriangle);
    }
    return currentTriangle;
  }

  /// Helper to generate the bottom cap of an extruded mesh with reversed winding for a CPU-side [TriangleMesh].
  static int _addOutlineAsReverseTriFan(TriangleMesh mesh, Polyline outline,
      vm.Vector3 normal, int currentTriangle, vm.Vector3 depth) {
    if (!outline.planeIsValid) return currentTriangle;
    int numTris = outline.length - 2;

    final bounds = outline.getBounds2D();
    double w = bounds.max.x - bounds.min.x;
    double h = bounds.max.y - bounds.min.y;
    double x = bounds.min.x;
    double y = bounds.min.y;

    vm.Vector3 v0 = outline.getVector3(0) + depth;
    for (int i = 0; i < numTris; i++) {
      vm.Vector3 v1 = outline.getVector3(i + 2) + depth;
      vm.Vector3 v2 = outline.getVector3(i + 1) + depth;

      List<vm.Vector2> texCoord = computeTexCoords(v2, v1, v0, x, y, w, h);

      currentTriangle =
          mesh.addTriangle(v2, v1, v0, normal, texCoord, currentTriangle);
    }
    return currentTriangle;
  }

  /// Helper to generate the two triangles that form a side wall from one edge of an outline for a CPU-side [TriangleMesh].
  static int _makeSideFromEdge(TriangleMesh mesh, Polyline outline, int index,
      int currentTriangle, vm.Vector3 depth) {
    vm.Vector3 p1 = outline.getVector3(index % outline.length);
    vm.Vector3 p2 = outline.getVector3((index + 1) % outline.length);
    vm.Vector3 normal = (p2 - p1).cross(depth).normalized();

    vm.Vector3 p1z = p1 + depth;
    vm.Vector3 p2z = p2 + depth;

    // TODO: Calculate correct texture coordinates for sides.
    List<vm.Vector2> texCoord = [vm.Vector2.zero(), vm.Vector2(1, 0), vm.Vector2(1, 1)];
    currentTriangle =
        mesh.addTriangle(p1, p2, p2z, normal, texCoord, currentTriangle);

    texCoord = [vm.Vector2.zero(), vm.Vector2(1, 1), vm.Vector2(0, 1)];
    currentTriangle =
        mesh.addTriangle(p1, p2z, p1z, normal, texCoord, currentTriangle);

    return currentTriangle;
  }
}
