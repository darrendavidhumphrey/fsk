import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Base class for model loaders.
abstract class FskModelLoader with LoggableClass {
  /// Standard vertex stride for FSK models (Pos, Tex, Norm, Color).
  static const int standardStride = 12;

  /// Helper to create a correction group for Y-up to Y-down conversion.
  static FskGroup createCorrectionGroup(String sceneId, FskSceneBase parentScene) {
    final correctionGroup = FskGroup('${sceneId}_correction', parentScene);
    // Y-axis 180 to face camera, Z-axis 180 to flip right-side up
    correctionGroup.transformable.rotation =
        vm.Vector3(0, vm.radians(180), vm.radians(180));
    return correctionGroup;
  }
}
