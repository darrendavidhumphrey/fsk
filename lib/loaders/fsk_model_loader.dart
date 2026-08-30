import 'package:vector_math/vector_math.dart' as vm;
import '../logging.dart';
import '../scene_graph/fsk_group.dart';
import '../scene_graph/fsk_scene_base.dart';

/// Base class for model loaders.
abstract class FskModelLoader with LoggableClass {
  /// Standard vertex stride for FSK models (Pos, Tex, Norm, Color).
  static const int standardStride = 12;

  /// Helper to create a correction group for model orientation
  static FskGroup createCorrectionGroup(String sceneId, FskSceneBase parentScene) {
    final correctionGroup = FskGroup('${sceneId}_correction', parentScene);
    // Correction group no longer needed, but keeping it for other uses like scaling
    correctionGroup.transformable.rotation =
        vm.Vector3(0, 0, 0);
    return correctionGroup;
  }
}
