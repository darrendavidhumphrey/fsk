import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsg/fsk.dart';
import 'package:fsg/vbo_filler.dart';

class FrameSceneExample extends FrameScene {

  bool skinLoaded = false;

  FrameSceneExample();


  @override
  void init(RenderingContext gl) {
    super.init(gl);
    loadSkin();
  }

  void loadSkin() async {
    String skinPath = "frames/GameScreen.xml";
    frameData = await FrameSceneParser.parseFromAssets(skinPath);

    skinLoaded = true;
    frameData.dumpTree();
  }

  @override
  void drawScene() async {
    if (!skinLoaded) return;
    super.drawScene();
    requestRepaint();
  }
}
