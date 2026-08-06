import 'package:flutter/foundation.dart';
import 'package:fsk/fsk.dart';

/// Base class for models loaded from external resources (OBJ, GLTF, etc.)
abstract class FskExternalModel extends FskGroup with ChangeNotifier {
  bool isLoaded = false;
  bool hasError = false;
  String? errorMessage;

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
}
