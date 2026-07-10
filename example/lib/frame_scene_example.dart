import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsk/fsk.dart';

class FrameSceneExample extends FrameScene {

  FrameSceneExample({super.navigationDelegate});

  @override
  void init(RenderingContext gl) {
    String skinPath = "frames/example6.xml";
    super.init(gl);
    loadSkin(skinPath);
  }

  @override
  void drawScene() async {
    if (!skinLoaded) {
      requestRepaint();
      return;
    }
    super.drawScene();
    requestRepaint();
  }
}
