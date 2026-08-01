import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

Color getCyclingColor({
  required double timeInSeconds,
  double cycleDurationSeconds = 10.0, // Default to 10 seconds for a full cycle
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
  double cycleDurationSeconds = 10.0, // Default to 10 seconds for a full cycle
  double saturation = 1.0,
  double value = 1.0,
}) {
  // Normalize time to a value between 0.0 and 1.0 based on cycleDuration
  final double normalizedTime =
      (timeInSeconds % cycleDurationSeconds) / cycleDurationSeconds;

  return normalizedTime * 25;
}

class AnimatedCheckerBoardScene extends FskScene {
  FskVertexBuffer exampleVbo = FskVertexBuffer();
  late PipelineKey pipelineKey;
  CheckerBoardUniforms? uniforms;

  AnimatedCheckerBoardScene({super.navigationDelegate}) {
    init();
  }

  void init() {
    final Size quadExtents = Size(500, 500);
    VboFiller.makeTexturedUnitQuad(
      Rect.fromLTWH(
        -quadExtents.width / 2,
        -quadExtents.height / 2,
        quadExtents.width,
        quadExtents.height,
      ),
      0.1,
      exampleVbo,
    );

    clearColor = Colors.white;
    exampleVbo.uploadData();

    // Create a pipeline key for this shader and associated settings
    pipelineKey = PipelineKey(
      vertShaderName: "CheckerBoardVertex",
      fragShaderName: "CheckerBoardFragment",
      layoutName: "CheckerBoardLayout",
      texturingEnabled: false,
    );

    uniforms = CheckerBoardUniforms(vertexShader: pipelineKey.vertShader, fragmentShader: pipelineKey.fragShader);

  }

  void drawVBO(gpu.RenderPass renderPass,gpu.HostBuffer transients, Matrix4 pMatrix, Matrix4 mvMatrix, Size viewportSize) {
    FSK().activatePipeline(pipelineKey, renderPass, v3t2Layout);

    exampleVbo.bind(renderPass);

    double cycleDuration = 2;

    DateTime now = DateTime.now();
    double timeInSeconds = now.millisecondsSinceEpoch / 1000.0;
    Color color1 = getCyclingColor(
      timeInSeconds: timeInSeconds,
      cycleDurationSeconds: cycleDuration,
    );

    Color color2 = getCyclingColor(
      timeInSeconds: timeInSeconds + 1,
      cycleDurationSeconds: cycleDuration,
    );

    double patternScale = getCyclingScale(
      timeInSeconds: timeInSeconds,
      cycleDurationSeconds: cycleDuration,
    );

    uniforms!.patternColor1 = color1;
    uniforms!.patternColor2 = color2;
    uniforms!.patternScale = patternScale;

    uniforms!.onUpdate(viewportSize);
    uniforms!.mvMatrix = mvMatrix.clone();
    uniforms!.pMatrix = pMatrix.clone();

    uniforms!.bind(renderPass,transients);

    exampleVbo.drawTriangles(renderPass);
  }

  @override
  void drawScene(gpu.RenderPass renderPass,gpu.HostBuffer transients) {
    // Scissor and viewport
    setupScissor(renderPass);
    drawVBO(renderPass, transients,pMatrix, mvMatrix, viewportSize);
  }
}
