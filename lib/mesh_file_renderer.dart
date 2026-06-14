import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsg/fsg.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

/// A renderer responsible for drawing a [WavefrontObjModel] to the screen.
///
/// This class manages the WebGL resources ([VertexBuffer] and [IndexBuffer])
/// and orchestrates the draw calls for each mesh within the model, applying
/// the correct materials and shader configurations.
class MeshFileRenderer {
  /// The vertex buffer containing the model's geometry.
  final VertexBuffer vbo;

  /// The index buffer that defines the order in which vertices are drawn.
  final IndexBuffer ibo;

  /// The loaded 3D model data.
  final WavefrontObjModel model;

  /// The WebGL rendering context.
  final RenderingContext gl;

  OneLightShader? shader;

  /// Creates a renderer for a specific model and initializes its GL resources.
  ///
  /// Upon creation, it immediately builds the index buffer for the given model,
  /// making the renderer ready to be drawn.
  MeshFileRenderer(this.gl, this.model)
      : ibo = IndexBuffer(gl),
        vbo = model.vertexBuffer {
    buildIndexBuffer();
  }

  /// Builds a single, consolidated [IndexBuffer] from all the meshes in the model.
  ///
  /// This method iterates through each mesh, calculates the total number of indices,
  /// requests a sufficiently large buffer, and then fills it with the index data
  /// from each mesh in sequence. Finally, it uploads the complete index data to the GPU.
  void buildIndexBuffer() {
    // Calculate the total number of indices required for the entire model.
    int indexCount = 0;
    for (var mesh in model.meshes) {
      indexCount += mesh.triangleIndices.length;
    }

    // Request a buffer from the IBO with the correct size.
    Int16Array? indexData = ibo.requestBuffer(indexCount);

    // Fill the buffer with index data from each mesh.
    if (indexData != null) {
      int j = 0;
      for (var mesh in model.meshes) {
        for (int i = 0; i < mesh.triangleIndices.length; i++, j++) {
          indexData[j] = mesh.triangleIndices[i];
        }
      }
    }

    // Upload the completed index data to the GPU.
    ibo.setActiveIndexCount(indexCount);
  }

  /// Configures and enables the lighting shader for drawing.
  void enableLightingShader(Matrix4 pMatrix, Matrix4 mvMatrix) {
    FSG().glStateManager.useProgram(shader!.program);
    ShaderList.setMatrixUniforms(shader!, pMatrix, mvMatrix);

    shader!.setLightPos(Vector3(40, 0, -200));
    shader!.setNMatrix(Matrix3.identity());
    shader!.setAmbientLight(Colors.grey[900]!);
    shader!.setDiffuseLight(Colors.white);
    shader!.setSpecularLight(Colors.white);
  }

  /// Sets the material properties on the currently active shader.
  void setMaterial(String materialName) {
    GlMaterial material = FSG().materials.getMaterial(materialName);
    shader!.setMaterialAmbient(material.ambient);
    shader!.setMaterialDiffuse(material.diffuse);
    shader!.setMaterialSpecular(material.specular);
    shader!.setShininess(material.shininess);
  }

  /// Draws the entire model.
  ///
  /// This method sets up the GL state, binds the vertex and index buffers,
  /// enables the shader, and then iterates through each mesh in the model.
  /// For each mesh, it sets the correct material and issues a `drawElements` call.
  void draw(Matrix4 pMatrix, Matrix4 mvMatrix) {
    shader ??= FSG().shaders.getShader<OneLightShader>();

    var gls = FSG().glStateManager;

    gls.setBlend(true);
    gls.setDepthTest(true);
    gls.setCullFace(true);
    gls.cullFace(WebGL.BACK);

    vbo.bind();
    ibo.bind();

    enableLightingShader(pMatrix, mvMatrix);

    // Draw each mesh with its specific material and index range.
    for (var mesh in model.meshes) {
      const int indexSize = 2; // Size of UNSIGNED_SHORT in bytes.
      String materialName =
          (mesh.materialName == null) ? "default" : mesh.materialName!;

      setMaterial(materialName);

      // Draw the elements for the current mesh, using its specific length and offset.
      gl.drawElements(WebGL.TRIANGLES, mesh.triangleIndices.length,
          WebGL.UNSIGNED_SHORT, mesh.bufferOffset * indexSize);
    }
    ibo.unbind();
    vbo.unbind();
  }
}
