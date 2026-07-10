import 'dart:ui';

import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsk/fsk.dart';

class FrameSceneExample extends FrameScene {



  FrameSceneExample({super.navigationDelegate});


  @override
  void init(RenderingContext gl) {
    String skinPath = "frames/GameScreen.xml";
    super.init(gl);
    loadSkin(skinPath);
  }

  @override
  void drawScene() async {
    if (!skinLoaded) return;
    super.drawScene();
    requestRepaint();
  }
}
