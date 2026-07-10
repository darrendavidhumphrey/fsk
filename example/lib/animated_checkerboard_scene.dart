import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsk/fsk.dart';
import 'package:fsk/vbo_filler.dart';

class AnimatedCheckerBoardScene extends FskScene {
  AnimatedCheckerBoardScene({super.navigationDelegate}) {
    VboFiller.makeTexturedUnitQuad(
      Rect.fromLTWH(-quadExtents.width/2, -quadExtents.height/2, quadExtents.width, quadExtents.height),
      0.1,
      exampleVbo
    );
  }

  VertexBuffer exampleVbo = VertexBuffer.v3t2();
  final Size quadExtents = Size(500, 500);

  Color color1 = Colors.blue;
  Color color2 = Colors.yellow;
  double patternScale = 5;
  CheckerBoardShader? shader;

  @override
  void init(RenderingContext gl) {
    super.init(gl);
    exampleVbo.init(gls);
    exampleVbo.uploadData();
  }

  @override
  void dispose() {}

  void drawVBO(Matrix4 pMatrix, Matrix4 mvMatrix) {
    shader ??= FSK().shaders.getShader<CheckerBoardShader>();
    gls.useProgram(shader!.program);
    ShaderList.setMatrixUniforms(shader!, pMatrix, mvMatrix);

    shader!.setPatternColor1(color1);
    shader!.setPatternColor2(color2);
    shader!.setPatternScale(patternScale);

    exampleVbo.bind();
    exampleVbo.drawTriangles();
    exampleVbo.unbind();
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

  double getCyclingScale({
    required double timeInSeconds,
    double cycleDurationSeconds =
    10.0, // Default to 10 seconds for a full cycle
    double saturation = 1.0,
    double value = 1.0,
  }) {
    // Normalize time to a value between 0.0 and 1.0 based on cycleDuration
    final double normalizedTime =
        (timeInSeconds % cycleDurationSeconds) / cycleDurationSeconds;

    return normalizedTime * 25;
  }

  @override
  void drawScene() async {
    super.drawScene();

    gls.setViewport(
      0,
      0,
      FSK.renderToTextureSize.toInt(),
      FSK.renderToTextureSize.toInt(),
    );
    gl.clear(WebGL.COLOR_BUFFER_BIT | WebGL.DEPTH_BUFFER_BIT);

    gls.activeTexture(WebGL.TEXTURE0);
    gls.setTexturingEnabled(false);

    gls.setBlend(true);
    gls.setCullFace(false);
    gls.clearColor(1, 1, 1, 1);
    gls.setDepthTest(false);
    gls.setDepthMask(false);

    gls.depthFunc(WebGL.LESS);
    gls.blendFuncSeparate(
      WebGL.SRC_ALPHA,
      WebGL.ONE_MINUS_SRC_ALPHA,
      WebGL.ONE,
      WebGL.ONE_MINUS_SRC_ALPHA,
    );

    double cycleDuration = 2;

    DateTime now = DateTime.now();
    double timeInSeconds = now.millisecondsSinceEpoch / 1000.0;
    color1 = getCyclingColor(
      timeInSeconds: timeInSeconds,
      cycleDurationSeconds: cycleDuration,
    );

    color2 = getCyclingColor(
      timeInSeconds: timeInSeconds + 1,
      cycleDurationSeconds: cycleDuration,
    );

    patternScale= getCyclingScale(
      timeInSeconds: timeInSeconds,
      cycleDurationSeconds: cycleDuration,
    );

    withPushedMatrix( () {
      drawVBO(pMatrix, mvMatrix);
    });
    requestRepaint();
  }
}