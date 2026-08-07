import 'package:flutter/foundation.dart';
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Base class for models loaded from external resources (OBJ, GLTF, etc.)
abstract class FskExternalModel extends FskGroup with ChangeNotifier {
  bool isLoaded = false;
  bool hasError = false;
  String? errorMessage;

  /// A group node used to handle model-specific coordinate system corrections
  /// (e.g., Y-up to Y-down) without affecting the root model's transform.
  FskGroup? correctionGroup;

  FskExternalModel(super.id, super.parentScene);

  void setLoaded() {
    isLoaded = true;
    hasError = false;
    parentScene.setNeedsUpdate();
    notifyListeners();
  }

  void setError(String message) {
    isLoaded = false;
    hasError = true;
    errorMessage = message;
    parentScene.setNeedsUpdate();
    notifyListeners();
  }

  /// Centers the model by translating the correction node based on the model's bounds.
  void centerModel() {
    if (correctionGroup == null) return;

    // 1. Calculate aggregate AABB of all meshes inside the correction group.
    // We want the bounds in the local space of the correctionGroup BEFORE its own transform is applied.
    final vm.Aabb3 bounds = vm.Aabb3.minMax(
      vm.Vector3.all(double.infinity),
      vm.Vector3.all(double.negativeInfinity),
    );

    for (final child in correctionGroup!.children) {
      final childAabb = child.getAabb();
      if (childAabb.min.x == double.infinity) continue;

      if (child is FskRenderableObject && child.transformable.isTransformed()) {
        bounds.hull(childAabb.transformed(
            child.transformable.getTransform(), vm.Aabb3()));
      } else {
        bounds.hull(childAabb);
      }
    }

    if (bounds.min.x == double.infinity) return;

    final vm.Vector3 center = bounds.center;

    // 2. Use 'anchor' to center the geometry.
    // In FskTransformable, anchor is applied BEFORE rotation and scale in the vertex path.
    // By setting anchor to -center, we move the geometry's center to the pivot point (0,0,0).
    correctionGroup!.transformable.anchor = -center;

    // Reset position to zero since we are now centering via the anchor pivot.
    correctionGroup!.transformable.position = vm.Vector3.zero();

    parentScene.setNeedsUpdate();
  }
}
