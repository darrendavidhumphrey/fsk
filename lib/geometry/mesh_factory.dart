import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// A utility class with static methods to create complex [FskMesh] objects
/// or generate [Float32List] vertex data.
class MeshFactory {
  // Private constructor to prevent instantiation of this utility class.
  MeshFactory._();

  /////////////////////////////////////////////////////////////////////////////
  // Public API Methods
  /////////////////////////////////////////////////////////////////////////////

  // --- FskMesh Creation ---

  /// Generates vertex data for a solid from its faces.
  static Float32List verticesFromSolidFaces(List<Polyline> faces, {Color color = Colors.white}) {
    int triangleCount = 0;
    for (var face in faces) {
      if (face.length > 2) {
        triangleCount += (face.length - 2);
      }
    }

    int newVertexCount = triangleCount * 3;
    final vertices = Float32List(newVertexCount * FskVertexBuffer.componentCount);
    final filler = VboFiller(vertices);
    for (var face in faces) {
      if (face.length > 2) {
        _addTexturedTriFan(filler, face, true, color: color);
      }
    }
    return vertices;
  }

  /// Creates an [FskMesh] by tessellating a list of [faces].
  static FskMesh meshFromFaces(String id, FskSceneBase scene, List<Polyline> faces,
      {Color color = Colors.white, FskShaderMaterial? material}) {
    return _createMesh(id, scene, faces, (filler, face) {
      _addTexturedTriFan(filler, face, true, color: color);
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
      {required String id, required FskSceneBase parentScene, required vm.Quad quad, required double thickness, required Color color,
      FskShaderMaterial? material}) {
    final outlines = createThickOutline3DFromQuad(quad, thickness);
    return meshFromColorOutlines(id, parentScene, outlines, color, material: material);
  }

  /// Creates a new [FskMesh] by extruding a list of [outlines] by a [depth] vector.
  /// This generates top, bottom, and side faces to create a closed 3D shape.
  static FskMesh extrude(String id, FskSceneBase scene, List<Polyline> outlines, vm.Vector3 depth,
      {Color color = Colors.white, FskShaderMaterial? material}) {
    if (outlines.isEmpty) {
      return FskMesh(id, scene, shaderMaterial: material);
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

    int totalTriangles = topCount * 2 + sideCount;
    int totalVertices = totalTriangles * 3;

    final mesh = FskMesh(id, scene, shaderMaterial: material);
    if (totalVertices > 0) {
      final vertices = Float32List(totalVertices * FskVertexBuffer.componentCount);
      final filler = VboFiller(vertices);

      // Add the top faces.
      for (var outline in outlines) {
        if (outline.planeIsValid) {
          _addExtrudedCap(filler, outline, vm.Vector3.zero(), outline.normal!, color, reverse: false);
        }
      }

      // Add the bottom faces (reversed winding order).
      for (var outline in outlines) {
        if (outline.planeIsValid) {
          _addExtrudedCap(filler, outline, depth, -outline.normal!, color, reverse: true);
        }
      }

      // Add the side walls.
      for (var outline in outlines) {
        _addExtrudedSides(filler, outline, depth, color);
      }

      mesh.vertices = vertices;
      mesh.uploadToGpu();
      mesh.renderer.addFskSubMesh(FskSubMesh(count: totalVertices, offset: 0));
      mesh.renderer.finalizeData();
    }

    return mesh;
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
      VboFiller filler, Polyline outline, bool generateNormals,{Color color = Colors.white}) {
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
        filler.addV3T2N3C4(v0, texCoord[0], normal, color);
        filler.addV3T2N3C4(v1, texCoord[1], normal, color);
        filler.addV3T2N3C4(v2, texCoord[2], normal, color);
      } else {
        // Fallback for when normals aren't requested (unlikely in current codebase)
        filler.addV3T2(v0, texCoord[0]);
        filler.addV3T2(v1, texCoord[1]);
        filler.addV3T2(v2, texCoord[2]);
      }
    }
  }

  /// Helper to generate a cap of an extruded mesh for a GPU-side [FskMesh].
  static void _addExtrudedCap(VboFiller filler, Polyline outline, vm.Vector3 offset, vm.Vector3 normal, Color color,
      {required bool reverse}) {
    int numTris = outline.length - 2;
    vm.Vector3 v0 = outline.getVector3(0) + offset;

    final bounds = outline.getBounds2D();
    double w = bounds.max.x - bounds.min.x;
    double h = bounds.max.y - bounds.min.y;
    double x = bounds.min.x;
    double y = bounds.min.y;

    for (int j = 0; j < numTris; j++) {
      vm.Vector3 v1, v2;
      if (reverse) {
        v1 = outline.getVector3(j + 2) + offset;
        v2 = outline.getVector3(j + 1) + offset;
      } else {
        v1 = outline.getVector3(j + 1) + offset;
        v2 = outline.getVector3(j + 2) + offset;
      }

      List<vm.Vector2> texCoord = computeTexCoords(v0, v1, v2, x, y, w, h);

      filler.addV3T2N3C4(v0, texCoord[0], normal, color);
      filler.addV3T2N3C4(v1, texCoord[1], normal, color);
      filler.addV3T2N3C4(v2, texCoord[2], normal, color);
    }
  }

  /// Helper to generate the two triangles that form a side wall from one edge of an outline for a GPU-side [FskMesh].
  static void _addExtrudedSides(VboFiller filler, Polyline outline, vm.Vector3 depth, Color color) {
    for (int i = 0; i < outline.length; i++) {
      vm.Vector3 p1 = outline.getVector3(i);
      vm.Vector3 p2 = outline.getVector3((i + 1) % outline.length);

      vm.Vector3 p1z = p1 + depth;
      vm.Vector3 p2z = p2 + depth;

      vm.Vector3 normal = (p2 - p1).cross(depth).normalized();

      // Triangle 1
      filler.addV3T2N3C4(p1, vm.Vector2(0, 0), normal, color);
      filler.addV3T2N3C4(p2, vm.Vector2(1, 0), normal, color);
      filler.addV3T2N3C4(p2z, vm.Vector2(1, 1), normal, color);

      // Triangle 2
      filler.addV3T2N3C4(p1, vm.Vector2(0, 0), normal, color);
      filler.addV3T2N3C4(p2z, vm.Vector2(1, 1), normal, color);
      filler.addV3T2N3C4(p1z, vm.Vector2(0, 1), normal, color);
    }
  }
}
