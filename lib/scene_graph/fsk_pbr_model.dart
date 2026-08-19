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
}
