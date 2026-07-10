import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsk/fsk.dart';

class BitmapTextScene extends FrameScene {
  BitmapTextScene({super.navigationDelegate});

  FrameTextNode? frameCountText;
  @override
  void dispose() {}

  @override
  void init(RenderingContext gl) {
    // Load text objects from skin file
    String skinPath = "frames/example4.xml";
    super.init(gl);

    loadSkin(skinPath);
  }

  @override
  void onSceneReady() {
    drawScene();
    frameCountText ??= findNodeByType<FrameTextNode>("FrameCount");
  }

  @override
  void drawScene() async {
    if (!skinLoaded) {
      requestRepaint();
      return;
    }

    // Access text object by ID in skin file
    frameCountText?.object!.setText("$frameCounter");

    super.drawScene();
    requestRepaint();
  }

}
