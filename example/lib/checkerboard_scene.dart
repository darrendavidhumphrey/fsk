import 'dart:ui';
import 'package:flutter/material.dart' hide Matrix4;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

class CheckerBoardScene extends FskFrameScene {
  CheckerBoardScene({super.navigationDelegate}) {
    init();
  }

  void init() {
    clearColor = Colors.white;
    frameSize = const Size(500, 500);
    use2DLayout = true; // Use the 2D box-fit and centering logic

    // Create a ReferenceBox that matches the 2D layout expectation (Origin at 0,0)
    final refBox = ReferenceBox(
      Vector3.zero(),
      Vector3(500, 0, 0),
      Vector3(0, 500, 0),
      Vector3(0, 0, 1),
    );

    final gridQuad = FskQuad(
      'checker',
      this,
      refBox,
      const Rect.fromLTWH(0, 0, 1, 1),
      Colors.white,
      'dummy',
      shaderMaterial: FskShaderMaterial.checkerboard,
    );

    final uniforms = gridQuad.uniforms as CheckerBoardUniforms;
    uniforms.patternColor1 = Colors.red;
    uniforms.patternColor2 = Colors.green;
    uniforms.useTexture = false;
    uniforms.patternScale = 50;

    addNode(gridQuad);

    isReady = true;
    navigationDelegate?.updateSceneMatrices(force: true);
  }
}
