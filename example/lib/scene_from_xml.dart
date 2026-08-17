import 'package:flutter/material.dart';
import 'package:fsk/fsk.dart';

class SceneFromXml extends FskScene {

  SceneFromXml({super.navigationDelegate}) : super.fromSkinFile("skins/example4.xml",clearColor: Colors.green);

  FskTextureText? frameCountText;
  FskTextureText? sourceCode1, sourceCode2, sourceCode3, top;
  FskQuad? penelope;

  /// Automatically invoked callback when skin loads successfully
  @override
  Future<void> onSkinReady() async {
    frameCountText ??= findNode<FskTextureText>("Text1");
    sourceCode1 ??= findNode<FskTextureText>("sourceCode1");
    sourceCode2 ??= findNode<FskTextureText>("sourceCode2");
    sourceCode3 ??= findNode<FskTextureText>("sourceCode3");
    top ??= findNode<FskTextureText>("Top");

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
}
