import 'package:flutter/material.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';

class FrameSceneExample extends FskFrameScene {

  FskBitmapText? frameCountText;
  FskBitmapText? sourceCode1, sourceCode2, sourceCode3;
  FskQuad? penelope;
  FrameSceneExample({super.navigationDelegate}) {
    // Load skin file
    String skinPath = "frames/example4.xml";

    clearColor = Colors.green;

    loadSkin(skinPath).then((_) {
      frameCountText ??= findNodeByType<FskBitmapText>("Text1");
      sourceCode1 ??= findNodeByType<FskBitmapText>("sourceCode1");
      sourceCode2 ??= findNodeByType<FskBitmapText>("sourceCode2");
      sourceCode3 ??= findNodeByType<FskBitmapText>("sourceCode3");

      penelope ??= findNodeByType<FskQuad>("penelope");
      penelope?.modulateColor = Colors.red;

      sourceCode1?.setText("01234");
      sourceCode2?.setText("01234");
      sourceCode3?.setText("01234");
    });
  }


  @override
  void dispose() {}

}
