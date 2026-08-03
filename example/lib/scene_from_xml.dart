import 'package:flutter/material.dart';
import 'package:fsk/fsk.dart';

class SceneFromXml extends FskFrameScene {

  FskBitmapText? frameCountText;
  FskBitmapText? sourceCode1, sourceCode2, sourceCode3, top;
  FskQuad? penelope;

  /// Automatically invoked callback when skin loads successfully
  @override
  Future<void> onSkinReady() async {
    clearColor = Colors.green;
    frameCountText ??= findNode<FskBitmapText>("Text1");
    sourceCode1 ??= findNode<FskBitmapText>("sourceCode1");
    sourceCode2 ??= findNode<FskBitmapText>("sourceCode2");
    sourceCode3 ??= findNode<FskBitmapText>("sourceCode3");
    top ??= findNode<FskBitmapText>("Top");

    penelope ??= findNode<FskQuad>("penelope");
    penelope?.modulateColor = Colors.red;

    sourceCode1?.text = "01234";
    sourceCode1?.maxLen = 1;
    sourceCode2?.text = "01234567";
    sourceCode2?.maxLen = 2;
  }

  @override
  void rebuildGeometry() {
    if (isReady && frameCountText != null) {
      frameCountText!.text = "Frames: $frameCount";
    }
    super.rebuildGeometry();
  }

  SceneFromXml({super.navigationDelegate}) : super.fromSkinFile("frames/example4.xml");
}
