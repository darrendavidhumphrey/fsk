import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsk/fsk.dart';

// IndexedStackScene contains a list of scenes and a current scene index.
// Only the current scene is rendered. Its behavior is analogous to the
// IndexedStack widget in flutter
class IndexedStackScene extends FskScene with ChangeNotifier {
  late FskScene _currentScene;
  final List<FskScene> scenes = [];

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  IndexedStackScene() {
    // HACK to fix async init problem -- return this scene until a real one is ready
    _currentScene = this;

  }

  @override
  @mustCallSuper
  void init(RenderingContext gl) {
    super.init(gl);
    notifyListeners();
  }

  // Add a scene to the list of scene
  void addScene(FskScene scene) {
    scene.init(gl);
    FSK().reuseTexture(renderToTextureId!, scene);
    scenes.add(scene);
    notifyListeners();
  }

  void setCurrentScene(int index) {
    if (index < scenes.length) {
      _currentScene = scenes[index];
      _currentIndex = index;
      _currentScene.requestRepaint();
      requestRepaint();
      notifyListeners();
    }
  }

  @override
  void setViewportSize(Size size) {
    super.setViewportSize(size);
    for (var scene in scenes) {
      scene.setViewportSize(size);
    }
  }

  FskScene currentScene() {
    return _currentScene;
  }


  @override
  void dispose() {
    for (var scene in scenes) {
      scene.dispose();
    }
    super.dispose();
  }

  @override
  void drawScene() {
    super.drawScene();

    _currentScene.drawScene();
    _currentScene.requestRepaint();
    requestRepaint();
  }
}
