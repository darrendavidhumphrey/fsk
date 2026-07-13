import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsk/fsk.dart';

class BitmapTextScene extends FrameScene {
  BitmapTextScene({super.navigationDelegate});

  FrameTextNode? frameCountText;
  FrameTextNode? sourceCode1, sourceCode2, sourceCode3;

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
    sourceCode1 ??= findNodeByType<FrameTextNode>("sourceCode1");
    sourceCode2 ??= findNodeByType<FrameTextNode>("sourceCode2");
    sourceCode3 ??= findNodeByType<FrameTextNode>("sourceCode3");

    sourceCode1?.object!.setText("01234");
    sourceCode2?.object!.setText("01234");
    sourceCode3?.object!.setText("01234");
  }

  @override
  void drawScene() async {
    if (!skinLoaded) {
      requestRepaint();
      return;
    }

    gls.clearColor(0,1,0,1);
    // Access text object by ID in skin file
    frameCountText?.object!.setText("$frameCounter");

    super.drawScene();
    requestRepaint();
  }

}
