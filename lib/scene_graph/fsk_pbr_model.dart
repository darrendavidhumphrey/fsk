import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;
import '../fsk.dart';

/// A specialized group node that implements a custom PBR rendering pass for its subtree.
/// This node overrides the standard draw traversal to inject PBR-specific uniforms
/// (like light position) into any child meshes using [PbrUniforms].
class FskPbrModel extends FskExternalModel {
  /// The world-space position of the light source for this model's PBR rendering.
  vm.Vector3 lightPosition = vm.Vector3(200, 200, 0);

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
    vm.Matrix4 pMatrix,
    vm.Matrix4 mvMatrix, // This is (Layout * CameraView)
    Size viewportSize,
  ) {
    if (!visible) return;

    // We override the custom recursive rendering to handle mixed node types
    // while still injecting environment state.
    _drawRecursive(this, renderPass, transients, pMatrix, mvMatrix, viewportSize);
  }

  void _drawRecursive(
    FskSceneObject node,
    gpu.RenderPass renderPass,
    gpu.HostBuffer transients,
    vm.Matrix4 proj,
    vm.Matrix4 view,
    Size viewportSize,
  ) {
    if (node is! FskRenderableObject || !node.visible) return;

    final renderer = node.renderer;
    if (renderer != null) {
      renderer.rebuildPipeline();

      // Inject environment state if the renderer supports it.
      // LightingUniforms and PbrUniforms now handle View-Space transformation automatically onUpdate.
      if (renderer.uniforms is PbrUniforms) {
        final pbr = renderer.uniforms as PbrUniforms;
        pbr.lightPos = lightPosition;
        pbr.debugMode = 0.0;
      } else if (renderer.uniforms is LightingUniforms) {
        final lighting = renderer.uniforms as LightingUniforms;
        lighting.lightPos = lightPosition;
      }
    }

    if (node is FskGroup) {
      final vm.Matrix4 currentMv = view.clone()..multiply(node.transformable.getTransform());

      for (final child in node.children) {
        _drawRecursive(
            child, renderPass, transients, proj, currentMv, viewportSize);
      }
    } else {
      node.draw(renderPass, transients, proj, view, viewportSize);
    }
  }
}
