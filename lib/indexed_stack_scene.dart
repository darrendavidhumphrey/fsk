import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsg/fsg.dart';

// IndexedStackScene contains a list of scenes and a current scene index.
// Only the current scene is rendered. Its behavior is analogous to the
// IndexedStack widget in flutter
class IndexedStackScene extends Scene with ChangeNotifier {
  late Scene _currentScene;
  late SceneNavigationDelegate _currentDelegate;
  final List<Scene> scenes = [];
  final Map<Scene, SceneNavigationDelegate> delegates = {};
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  IndexedStackScene() {
    // HACK to fix async init problem -- return this scene until a real one is ready
    _currentScene = this;
    // HACK to fix async init problem -- create a temp delegate until a real one is ready
    _currentDelegate = StaticViewDelegate();
  }

  @override
  @mustCallSuper
  void init(RenderingContext gl) {
    super.init(gl);
    notifyListeners();
  }

  // Add a scene to the list of scenes, optionally with a delegate.
  void addScene(Scene scene, SceneNavigationDelegate delegate) {
    scene.init(gl);
    FSG().reuseTexture(renderToTextureId!, scene);
    scenes.add(scene);
    delegates[scene] = delegate;
    notifyListeners();
  }

  void setCurrentScene(int index) {
    if (index < scenes.length) {
      _currentScene = scenes[index];
      _currentIndex = index;
      _currentDelegate = delegates[_currentScene]!;
      _currentDelegate.setScene(_currentScene);
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

  Scene currentScene() {
    return _currentScene;
  }

  SceneNavigationDelegate currentDelegate() {
    return _currentDelegate;
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
