import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart';

/// Base class for model loaders.
abstract class FskModelLoader with LoggableClass {
  /// Standard vertex stride for FSK models (Pos, Tex, Norm, Color).
  static const int standardStride = 12;

  /// Helper to create a correction group for Y-up to Y-down conversion.
  static FskGroup createCorrectionGroup(String sceneId, FskSceneBase parentScene) {
    final correctionGroup = FskGroup('${sceneId}_correction', parentScene);
    // Y-axis 180 to face camera, Z-axis 180 to flip right-side up
    correctionGroup.transformable.rotation =
        Vector3(0, radians(180), radians(180));
    return correctionGroup;
  }
}
