import 'package:flutter/cupertino.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsk/fsk.dart';

class ShaderParamsExample extends FrameScene {
  ShaderParamsExample({super.navigationDelegate});
  UniformValue? modulateUniform;
  bool ready = false;

  @override
  void init(RenderingContext gl) {
    String skinPath = "frames/example6.xml";
    super.init(gl);
    loadSkin(skinPath);
  }

  @override
  void onSceneReady() {
    super.onSceneReady();
    modulateUniform = findObjectUniform("PenelopeModulate","uModulateColor");
    ready = true;
  }

  Color getCyclingColor({
    required double timeInSeconds,
    double cycleDurationSeconds =
    10.0, // Default to 10 seconds for a full cycle
    double saturation = 1.0,
    double value = 1.0,
  }) {
    // Normalize time to a value between 0.0 and 1.0 based on cycleDuration
    final double normalizedTime =
        (timeInSeconds % cycleDurationSeconds) / cycleDurationSeconds;

    // Map the normalized time to a hue angle (0.0 to 360.0 degrees)
    final double hue = normalizedTime * 360.0;

    // Create an HSVColor and convert it to a standard Color object
    final HSVColor hsvColor = HSVColor.fromAHSV(1.0, hue, saturation, value);
    return hsvColor.toColor();
  }

  @override
  void drawScene() async {
    if (!skinLoaded || !ready) {
      requestRepaint();
      return;
    }

    DateTime now = DateTime.now();
    double timeInSeconds = now.millisecondsSinceEpoch / 1000.0;
    var color = getCyclingColor(timeInSeconds: timeInSeconds,cycleDurationSeconds: 2);

    modulateUniform?.value = color;


    super.drawScene();
    requestRepaint();
  }
}
