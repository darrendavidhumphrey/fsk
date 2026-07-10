import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math_64.dart';

/// A record type representing a unique combination of position, texture coordinate,
/// and normal indices. Used as a key to de-duplicate vertices.
typedef _VertexCombo = (int, int, int);

/// Represents a single face from the OBJ file, which can be a triangle or a polygon.
class Face {
  /// A list of vertex indices that form one or more triangles.
  final List<int> corners;

  /// Creates a Face and immediately triangulates it if it's a polygon.
  Face(List<int> faceCorners) : corners = toTriangleIndices(faceCorners);

  /// Converts a polygon (an n-gon) into a list of triangles.
  ///
  /// This uses a simple fan triangulation method, which works well for convex
  /// polygons but may produce incorrect results for concave ones.
  static List<int> toTriangleIndices(List<int> faceCorners) {
    if (faceCorners.length == 3) {
      return faceCorners; // Already a triangle
    }

    List<int> result = [];
    // Create a triangle fan from the first vertex.
    for (int i = 0; i < faceCorners.length - 2; i++) {
      result.add(faceCorners[0]);
      result.add(faceCorners[i + 1]);
      result.add(faceCorners[i + 2]);
    }
    return result;
  }
}

/// Represents a sub-mesh within the OBJ model.
///
/// A mesh is a collection of faces that share the same material.
class Mesh {
  /// The name of the material applied to this mesh.
  String? materialName;

  /// The flat list of vertex indices that form the triangles of this mesh.
  final List<int> triangleIndices = [];

  /// The starting offset of this mesh's indices in the final Index Buffer Object.
  final int bufferOffset;

  /// Creates a mesh from a list of faces.
  Mesh(List<Face> faces, {required this.bufferOffset, this.materialName}) {
    for (var face in faces) {
      triangleIndices.addAll(face.corners);
    }
  }
}

/// Represents a 3D model loaded from a Wavefront OBJ file.
///
/// This class handles parsing the OBJ file content, de-duplicating vertices,
/// building the vertex and index data, and organizing the model into meshes
/// based on the materials defined in the file.
class WavefrontObjModel {
  /// The vertex buffer containing the unique, interleaved vertex data for the model.
  final VertexBuffer vertexBuffer = VertexBuffer.v3t2n3();

  /// A list of sub-meshes, each corresponding to a different material.
  List<Mesh> meshes = [];

  /// The rendering context used to create the vertex buffer.
  final GlStateManager gls;

  // Internal state for parsing.
  List<Face> _currentMeshFaces = [];
  String _currentMaterialName = 'defaultMaterial';
  int _iboOffset = 0;

  /// Finalizes the current mesh being parsed and adds it to the `meshes` list.
  void _finalizeCurrentMesh() {
    if (_currentMeshFaces.isNotEmpty) {
      final newMesh = Mesh(
        _currentMeshFaces,
        bufferOffset: _iboOffset,
        materialName: _currentMaterialName,
      );
      meshes.add(newMesh);
      _iboOffset += newMesh.triangleIndices.length;
      _currentMeshFaces = []; // Reset for the next mesh
    }
  }

  /// Parses the OBJ file content from a string.
  ///
  /// This method uses an efficient two-pass approach:
  /// 1. A pre-scan pass counts the number of unique vertices to pre-allocate the
  ///    [VertexBuffer] with the exact required size.
  /// 2. The main pass parses all vertex attributes, populates the vertex buffer,
  ///    builds the face indices, and groups them into meshes.
  void loadFromString(String objFileContent) {
    // Temporary lists to hold the raw attribute data from the file.
    List<Vector3> tempPositions = [];
    List<Vector2> tempTextureCoordinates = [];
    List<Vector3> tempNormals = [];

    HashMap<_VertexCombo, int> uniqueVertexMap = HashMap();
    int nextAvailableIndex = 0;

    // --- PRE-SCAN PASS ---
    // Pre-scan the file to determine the exact number of unique vertices needed.
    // This is more efficient than incrementally growing the buffer.
    List<String> lines = LineSplitter().convert(objFileContent);
    for (String line in lines) {
      if (line.startsWith('f ')) {
        List<String> parts = line.split(' ');
        for (int i = 1; i < parts.length; i++) {
          List<String> indicesStr = parts[i].split('/');
          if (indicesStr.length == 3) {
            final combo = (
              int.parse(indicesStr[0]) - 1, // pos
              int.parse(indicesStr[1]) - 1, // tex
              int.parse(indicesStr[2]) - 1, // norm
            );
            // If this combination of attributes is new, assign it a new index.
            uniqueVertexMap.putIfAbsent(combo, () => nextAvailableIndex++);
          }
        }
      }
    }

    // --- MAIN PARSING PASS ---

    // Allocate the vertex buffer with the final, correct size.
    vertexBuffer.init(gls);
    final vboData = vertexBuffer.requestBuffer(uniqueVertexMap.length)!;
    final filler = VboFiller(vboData,vertexBuffer);

    // Reset state for the main parsing pass.
    uniqueVertexMap.clear();
    nextAvailableIndex = 0;

    for (String line in lines) {
      List<String> parts = line.split(' ');
      String prefix = parts[0];

      if (prefix == "v") {
        tempPositions.add(Vector3(
          double.parse(parts[1]),
          double.parse(parts[2]),
          double.parse(parts[3]),
        ));
      } else if (prefix == "vt") {
        tempTextureCoordinates.add(Vector2(
          double.parse(parts[1]),
          double.parse(parts[2]),
        ));
      } else if (prefix == "vn") {
        tempNormals.add(Vector3(
          double.parse(parts[1]),
          double.parse(parts[2]),
          double.parse(parts[3]),
        ));
      } else if (prefix == "usemtl") {
        _finalizeCurrentMesh();
        _currentMaterialName = parts[1];
      } else if (prefix == "f") {
        List<int> faceCorners = [];
        for (int i = 1; i < parts.length; i++) {
          List<String> indicesStr = parts[i].split('/');
          if (indicesStr.length == 3) {
            final currentCombination = (
              int.parse(indicesStr[0]) - 1, // pos
              int.parse(indicesStr[1]) - 1, // tex
              int.parse(indicesStr[2]) - 1, // norm
            );

            int vertexIndex = uniqueVertexMap.putIfAbsent(currentCombination, () {
              final newIndex = nextAvailableIndex++;
              // This is a new, unique vertex. Write its data to the buffer.
              filler.addV3T2N3(
                tempPositions[currentCombination.$1],
                tempTextureCoordinates[currentCombination.$2],
                tempNormals[currentCombination.$3],
              );
              return newIndex;
            });
            faceCorners.add(vertexIndex);
          }
        }
        _currentMeshFaces.add(Face(faceCorners));
      } else if (prefix == "o" || prefix == "g") {
        _finalizeCurrentMesh();
      }
    }

    _finalizeCurrentMesh(); // Finalize the last mesh in the file
    vertexBuffer.setActiveVertexCount(uniqueVertexMap.length);
  }

  /// Creates a model and initializes it with the rendering context.
  WavefrontObjModel(this.gls);

  /// Creates a [WavefrontObjModel] by loading and parsing a file from the
  /// application's asset bundle.
  static Future<WavefrontObjModel> fromAsset(
      String assetPath, GlStateManager gls) async {
    try {
      final objFileContent = await rootBundle.loadString(assetPath);
      final objModel = WavefrontObjModel(gls);
      objModel.loadFromString(objFileContent);
      return objModel;
    } catch (e, s) {
      // Re-throw with more context for easier debugging.
      throw Exception('Failed to load OBJ asset from "$assetPath": $e\n$s');
    }
  }
}
