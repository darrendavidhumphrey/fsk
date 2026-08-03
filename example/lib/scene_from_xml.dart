import 'package:flutter/material.dart';
import 'package:fsk/fsk.dart';

class SceneFromXml extends FskFrameScene {

  FskBitmapText? frameCountText;
  FskBitmapText? sourceCode1, sourceCode2, sourceCode3;
  FskQuad? penelope;

  /// Automatically invoked callback when skin loads successfully
  @override
  Future<void> onSkinReady() async {
    frameCountText ??= findNode<FskBitmapText>("Text1");
    sourceCode1 ??= findNode<FskBitmapText>("sourceCode1");
    sourceCode2 ??= findNode<FskBitmapText>("sourceCode2");
    sourceCode3 ??= findNode<FskBitmapText>("sourceCode3");

    penelope ??= findNode<FskQuad>("penelope");
    penelope?.modulateColor = Colors.red;

    sourceCode1?.text = "01234";
    sourceCode2?.text = "01234";
    sourceCode3?.text = "01234";
  }

  SceneFromXml({super.navigationDelegate}) : super.fromSkinFile("frames/example4.xml");
}
