import 'package:flutter/material.dart' hide Matrix4;
import 'package:fsk/fsk.dart';

Color getCyclingColor({
  required double timeInSeconds,
  double cycleDurationSeconds = 10.0,
  double saturation = 1.0,
  double value = 1.0,
}) {
  final double normalizedTime =
      (timeInSeconds % cycleDurationSeconds) / cycleDurationSeconds;
  final double hue = normalizedTime * 360.0;
  final HSVColor hsvColor = HSVColor.fromAHSV(1.0, hue, saturation, value);
  return hsvColor.toColor();
}

double getCyclingScale({
  required double timeInSeconds,
  double cycleDurationSeconds = 10.0,
}) {
  final double normalizedTime =
      (timeInSeconds % cycleDurationSeconds) / cycleDurationSeconds;
  return normalizedTime * 25;
}

class AnimatedCheckerBoardScene extends FskFrameScene {
  FskQuad? checkerQuad;

  AnimatedCheckerBoardScene({super.navigationDelegate});

  @override
  Future<void> init() async {
    if (initStarted) return;
    await super.init();
    clearColor = Colors.white;
    checkerQuad = FskQuad.centered(
      'checker',
      this,
      const Size(500, 500),
      shaderMaterial: FskShaderMaterial.checkerboard,
    );

    addNode(checkerQuad!);

    isReady = true;
  }

  @override
  void rebuildGeometry() {
    if (!isReady) return;
    useBoxFitLayout = false;
    final uniforms = checkerQuad!.uniforms as CheckerBoardUniforms;

    double cycleDuration = 2;
    double timeInSeconds = DateTime.now().millisecondsSinceEpoch / 1000.0;

    uniforms.patternColor1 = getCyclingColor(
      timeInSeconds: timeInSeconds,
      cycleDurationSeconds: cycleDuration,
    );

    uniforms.patternColor2 = getCyclingColor(
      timeInSeconds: timeInSeconds + 1,
      cycleDurationSeconds: cycleDuration,
    );

    uniforms.patternScale = getCyclingScale(
      timeInSeconds: timeInSeconds,
      cycleDurationSeconds: cycleDuration,
    );

    super.rebuildGeometry();
  }
}
