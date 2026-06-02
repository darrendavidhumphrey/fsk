import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsg/fsg.dart';
import 'package:fsg_examples/animated_checkerboard_scene.dart';
import 'package:fsg_examples/orbitview_scene.dart';

import 'checkerboard_scene.dart';

class IndexedScene extends Scene {
  late Scene _currentScene;
  final List<Scene> scenes = [];
  final Map<Scene, SceneNavigationDelegate> delegates = {};
  int _currentIndex = 0;
  IndexedScene();

  void setSceneIndex(int index) {
    if (index < scenes.length) {
      _currentScene = scenes[index];
      _currentIndex = index;
      requestRepaint();
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
    if (scenes.length > _currentIndex) {
      return scenes[_currentIndex];
    }
    return this;
  }

  SceneNavigationDelegate? currentDelegate() {
    if (scenes.length > _currentIndex) {
      return delegates[scenes[_currentIndex]];
    }
    return null;
  }

  @override
  void init(RenderingContext gl) {
    super.init(gl);

    // TODO: Move into FSG base
    // TODO: Do this in a derived class
    var checker = CheckerBoardScene();
    checker.init(gl);
    FSG().reuseTexture(renderToTextureId!, checker);
    scenes.add(checker);

    var animatedChecker = AnimatedCheckerBoardScene();
    animatedChecker.init(gl);
    FSG().reuseTexture(renderToTextureId!, animatedChecker);
    scenes.add(animatedChecker);

    var orbitScene = OrbitViewScene();
    orbitScene.init(gl);

    var orbitView = OrbitView();
    FSG().reuseTexture(renderToTextureId!, orbitScene);
    scenes.add(orbitScene);

    delegates[orbitScene] = orbitView;

    _currentScene = scenes[0];
  }

  @override
  void dispose() {}

  @override
  void drawScene() {
    _currentScene.drawScene();
    _currentScene.requestRepaint();
    requestRepaint();
  }
}
