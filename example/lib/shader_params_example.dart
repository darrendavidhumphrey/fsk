import 'package:flutter/material.dart';
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' as vm;

class ShaderParamsExample extends FskScene {
  ShaderParamsExample({super.navigationDelegate});
  
  bool ready = false;

  @override
  Future<void> onInit() async {
    await super.onInit();
    // Load a skin or create objects manually
    // For this example, we'll just create a quad and animate its color
    
    final quad = FskQuad.centered(
      "animated_quad",
      this,
      const Size(400, 400),
      modulateColor: Colors.white,
    );
    addNode(quad);
    
    ready = true;
  }

  Color getCyclingColor({
    required double timeInSeconds,
    double cycleDurationSeconds = 2.0,
    double saturation = 1.0,
    double value = 1.0,
  }) {
    final double normalizedTime = (timeInSeconds % cycleDurationSeconds) / cycleDurationSeconds;
    final double hue = normalizedTime * 360.0;
    return HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
  }

  @override
  void updateAnimations(DateTime now) {
    super.updateAnimations(now);
    if (!ready) return;

    final double timeInSeconds = now.millisecondsSinceEpoch / 1000.0;
    final color = getCyclingColor(timeInSeconds: timeInSeconds);

    final quad = findNode<FskQuad>("animated_quad");
    if (quad != null) {
      quad.modulateColor = color;
    }
  }
}
