import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart';

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
  final FskVertexBuffer vertexBuffer = FskVertexBuffer();

  /// A list of sub-meshes, each corresponding to a different material.
  List<Mesh> meshes = [];

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
  ///    [FskVertexBuffer] with the exact required size.
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
    List<String> lines = LineSplitter().convert(objFileContent);
    for (String line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      
      List<String> parts = trimmed.split(RegExp(r'\s+'));
      if (parts[0] != 'f') continue;

      for (int i = 1; i < parts.length; i++) {
        List<String> indicesStr = parts[i].split('/');
        
        int p = -1, t = -1, n = -1;
        if (indicesStr.isNotEmpty && indicesStr[0].isNotEmpty) p = int.parse(indicesStr[0]) - 1;
        if (indicesStr.length > 1 && indicesStr[1].isNotEmpty) t = int.parse(indicesStr[1]) - 1;
        if (indicesStr.length > 2 && indicesStr[2].isNotEmpty) n = int.parse(indicesStr[2]) - 1;
        
        final combo = (p, t, n);
        uniqueVertexMap.putIfAbsent(combo, () => nextAvailableIndex++);
      }
    }

    // --- MAIN PARSING PASS ---

    // Allocate the vertex buffer with the final, correct size.
    final totalUniqueVertices = uniqueVertexMap.length;
    vertexBuffer.requestBuffer(totalUniqueVertices);
    final filler = VboFiller(vertexBuffer);

    // Reset state for the main parsing pass.
    uniqueVertexMap.clear();
    nextAvailableIndex = 0;

    // Reset attribute data for the main pass
    tempPositions.clear();
    tempTextureCoordinates.clear();
    tempNormals.clear();

    for (String line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      List<String> parts = trimmed.split(RegExp(r'\s+'));
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
          
          int p = -1, t = -1, n = -1;
          if (indicesStr.isNotEmpty && indicesStr[0].isNotEmpty) p = int.parse(indicesStr[0]) - 1;
          if (indicesStr.length > 1 && indicesStr[1].isNotEmpty) t = int.parse(indicesStr[1]) - 1;
          if (indicesStr.length > 2 && indicesStr[2].isNotEmpty) n = int.parse(indicesStr[2]) - 1;
          
          final currentCombination = (p, t, n);

          int vertexIndex = uniqueVertexMap.putIfAbsent(currentCombination, () {
            final newIndex = nextAvailableIndex++;
            
            // Get position (required)
            final pos = tempPositions[currentCombination.$1];
            
            // Get texture coords or default to zero
            final tex = (currentCombination.$2 >= 0 && currentCombination.$2 < tempTextureCoordinates.length)
                ? tempTextureCoordinates[currentCombination.$2]
                : Vector2.zero();
                
            // Get normal or default to zero
            final norm = (currentCombination.$3 >= 0 && currentCombination.$3 < tempNormals.length)
                ? tempNormals[currentCombination.$3]
                : Vector3.zero();

            // This is a new, unique vertex. Write its data to the buffer.
            filler.addV3T2N3(pos, tex, norm);
            return newIndex;
          });
          faceCorners.add(vertexIndex);
        }
        _currentMeshFaces.add(Face(faceCorners));
      } else if (prefix == "o" || prefix == "g") {
        _finalizeCurrentMesh();
      }
    }

    _finalizeCurrentMesh(); // Finalize the last mesh in the file
  }

  /// Creates a model and initializes it with the rendering context.
  WavefrontObjModel();

  static Future<FskGroup> load(
    String assetPath,
    FskScene scene,
    String id, {
    FskShaderMaterial? shaderMaterial,
  }) async {
    final model = await WavefrontObjModel.fromAsset(assetPath);
    final rootGroup = FskGroup('${id}_root', scene);

    // Create the correction group to handle Y-up -> Y-down and facing direction
    final correctionGroup = FskGroup('${id}_correction', scene);
    // Y-axis 180 to face camera, Z-axis 180 to flip right-side up
    correctionGroup.transformable.rotation = Vector3(0, radians(180), radians(180));
    rootGroup.addNode(correctionGroup);

    // Create the actual mesh and add it to the correction group
    final mesh = model.createIndexedMesh(scene, id, shaderMaterial: shaderMaterial);
    correctionGroup.addNode(mesh);

    return rootGroup;
  }

  /// Creates an [FskIndexedMesh] from this model.
  FskIndexedMesh createIndexedMesh(FskScene scene, String id, {FskShaderMaterial? shaderMaterial}) {
    final indexedMesh = FskIndexedMesh(id, scene, shaderMaterial: shaderMaterial);

    // 1. Assign vertex data to Mesh
    if (vertexBuffer.vertexData != null) {
      indexedMesh.vertices = Float32List.fromList(vertexBuffer.vertexData!);
    }

    // 2. Build consolidated index buffer for Mesh
    int totalIndices = 0;
    for (var mesh in meshes) {
      totalIndices += mesh.triangleIndices.length;
    }

    final meshIndices = Uint16List(totalIndices);
    int j = 0;
    for (var mesh in meshes) {
      for (int i = 0; i < mesh.triangleIndices.length; i++, j++) {
        meshIndices[j] = mesh.triangleIndices[i];
      }

      // Add submesh to renderer
      indexedMesh.renderer.addSubMesh(SubMesh(
        indexCount: mesh.triangleIndices.length,
        firstIndex: mesh.bufferOffset,
        materialName: mesh.materialName,
        material: mesh.materialName != null ? FSK().materials.getMaterial(mesh.materialName!) : null,
      ));
    }
    indexedMesh.indices = meshIndices;

    indexedMesh.uploadToGpu();
    indexedMesh.renderer.finalizeData();
    return indexedMesh;
  }

  /// Creates a [WavefrontObjModel] by loading and parsing a file from the
  /// application's asset bundle.
  static Future<WavefrontObjModel> fromAsset(
      String assetPath) async {
    try {
      final objFileContent = await rootBundle.loadString(assetPath);
      final objModel = WavefrontObjModel();
      objModel.loadFromString(objFileContent);
      return objModel;
    } catch (e, s) {
      // Re-throw with more context for easier debugging.
      throw Exception('Failed to load OBJ asset from "$assetPath": $e\n$s');
    }
  }

  static Future<FskIndexedMesh> indexedMeshFromAsset(
      String assetPath,
      FskScene scene,
      String id,
      {FskShaderMaterial? shaderMaterial}
      ) async {
    final model = await WavefrontObjModel.fromAsset(assetPath);
    return model.createIndexedMesh(scene, id, shaderMaterial: shaderMaterial);
  }
}
