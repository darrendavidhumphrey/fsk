import 'dart:ui';

import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsk/fsk.dart';
import 'animated_checkerboard_scene.dart';
import 'bitmap_text_scene.dart';
import 'orbitview_scene.dart';
import 'checkerboard_scene.dart';
import 'frame_scene_example.dart';

// The example scenes are placed in an IndexedStackScene that corresponds
// with the IndexedStack flutter widget to draw only one example scene
// at a time.
class ExampleScenes extends IndexedStackScene {

  ExampleScenes();

  @override
  void init(RenderingContext gl) {
    super.init(gl);

    addScene(CheckerBoardScene( navigationDelegate: OrthoViewDelegate()));
    addScene(AnimatedCheckerBoardScene(navigationDelegate: StaticViewDelegate()));
    addScene(OrbitViewScene(navigationDelegate: OrbitViewDelegate()));
    addScene(BitmapTextScene(navigationDelegate: OrthoViewDelegate()));
    addScene(FrameSceneExample( navigationDelegate: OrthoViewDelegate()));

    setCurrentScene(0);
  }
}
