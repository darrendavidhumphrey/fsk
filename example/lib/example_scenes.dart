import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsg/fsk.dart';
import 'package:fsg/indexed_stack_scene.dart';
import 'package:fsg_examples/animated_checkerboard_scene.dart';
import 'package:fsg_examples/bitmap_text_scene.dart';
import 'package:fsg_examples/orbitview_scene.dart';
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

    addScene(CheckerBoardScene(),StaticViewDelegate());
    addScene(AnimatedCheckerBoardScene(),StaticViewDelegate());
    addScene(OrbitViewScene(),OrbitViewDelegate());
    addScene(BitmapTextScene(),OrbitViewDelegate());
    addScene(FrameSceneExample(),OrbitViewDelegate());

    setCurrentScene(0);
  }
}
