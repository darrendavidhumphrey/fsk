import 'package:flutter/material.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';

class FrameSceneExample extends FrameScene {

  FrameTextNode? frameCountText;
  FrameTextNode? sourceCode1, sourceCode2, sourceCode3;
  FrameQuadNode? penelope;
  FrameSceneExample({super.navigationDelegate}) {
    // Load skin file
    String skinPath = "frames/example4.xml";

    clearColor = Colors.green;

    loadSkin(skinPath).then((_) {
      frameCountText ??= findNodeByType<FrameTextNode>("Text1");
      sourceCode1 ??= findNodeByType<FrameTextNode>("sourceCode1");
      sourceCode2 ??= findNodeByType<FrameTextNode>("sourceCode2");
      sourceCode3 ??= findNodeByType<FrameTextNode>("sourceCode3");

      penelope ??= findNodeByType<FrameQuadNode>("penelope");
      penelope?.object!.modulateColor = Colors.red;

      sourceCode1?.object!.setText("01234");
      sourceCode2?.object!.setText("01234");
      sourceCode3?.object!.setText("01234");
    });
  }



  @override
  void dispose() {}

  @override
  void drawScene(gpu.RenderPass renderPass,gpu.HostBuffer transients) {
    if (!skinLoaded) {
      return;
    }

    super.drawScene(renderPass,transients);
  }
}
