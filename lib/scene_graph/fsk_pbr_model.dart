import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';
import '../fsk.dart';

/// A specialized group node that implements a custom PBR rendering pass for its subtree.
/// This node overrides the standard draw traversal to inject PBR-specific uniforms
/// (like light position) into any child meshes using [PbrUniforms].
class FskPbrModel extends FskExternalModel {
  /// The world-space position of the light source for this model's PBR rendering.
  Vector3 lightPosition = Vector3(200, 200, 0);

  FskPbrModel(super.id, super.parentScene);

  /// Creates and loads a PBR model from a GLTF asset in a single step.
  static Future<FskPbrModel> loadFromAssets({
    required String assetFile,
    required FskSceneBase parentScene,
    required String sceneId,
    void Function(FskPbrModel model)? onModelLoaded,
  }) async {
    final model = FskPbrModel(sceneId, parentScene);
    await FskGltfLoader.loadFromAssets(
      assetFile: assetFile,
      parentScene: parentScene,
      rootNode: model,
    );

    if (model.isLoaded) {
      onModelLoaded?.call(model);
    }

    return model;
  }

  @override
  void draw(
    gpu.RenderPass renderPass,
    gpu.HostBuffer transients,
    Matrix4 pMatrix,
    Matrix4 mvMatrix,
    Size viewportSize,
  ) {
    if (!visible) return;
    // We initiate the custom recursive rendering starting from this node.
    _renderRecursive(this, renderPass, transients, pMatrix, mvMatrix, viewportSize);
  }

  void _renderRecursive(
    FskSceneObject node,
    gpu.RenderPass renderPass,
    gpu.HostBuffer transients,
    Matrix4 proj,
    Matrix4 view,
    Size viewportSize,
  ) {
    bool isVisible = true;
    Matrix4 currentMv = view;

    if (node is FskRenderableObject) {
      if (!node.visible) return;
      isVisible = node.visible;
      // Hierarchical math: Post-multiplication (View * Local)
      currentMv = view.clone()..multiply(node.transformable.getTransform());
    }

    if (!isVisible) return;

    if (node is FskIndexedMesh) {
      final renderer = node.renderer;
      renderer.rebuildPipeline();

      final uniforms = renderer.uniforms!;
      uniforms.onUpdate(viewportSize);

      // No need to clone these matrix assignments -- the setter method in
      // uniforms is calling copyInto()
      uniforms.mvMatrix = currentMv;
      uniforms.pMatrix = proj;

      // Update light position for PBR materials
      if (uniforms is PbrUniforms) {
        uniforms.setValueSilent(PbrUniforms.kLightPosKey, lightPosition);
        uniforms.setValueSilent(PbrUniforms.kDebugModeKey, 0.0); // Full PBR
      }

      FSK().activatePipeline(renderer.pipelineKey!, renderPass, renderer.layout);

      renderer.vbo.bind(renderPass);

      for (var subMesh in renderer.subMeshes) {
        if (subMesh.textureInfo != null) {
          uniforms.texture = subMesh.textureInfo!.texture;
          uniforms.samplerOptions = subMesh.textureInfo!.samplerOptions;
        }

        if (subMesh.material != null) {
          uniforms.applyMaterial(subMesh.material!);
        }

        uniforms.bind(renderPass, transients);

        renderer.ibo.bind(renderPass, offsetInIndices: subMesh.firstIndex);
        renderer.ibo.drawTrianglesIndexed(renderPass, count: subMesh.indexCount);
      }
    }

    if (node is FskGroup) {
      for (final child in node.children) {
        _renderRecursive(child, renderPass, transients, proj, currentMv, viewportSize);
      }
    }
  }
}
