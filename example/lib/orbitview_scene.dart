import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

class OrbitViewScene extends FskScene {

  VertexBuffer exampleVbo = VertexBuffer();
  GridUniforms? uniforms;
  late PipelineKey pipelineKey;

  OrbitViewScene({super.navigationDelegate}) {
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
      vertShaderName: "GridVertex",
      fragShaderName: "GridFragment",
      depthTestEnabled: false,
      depthWriteEnabled: false,
      depthCompareOperation: gpu.CompareFunction.greater,
      texturingEnabled: false,
      blendEnabled: true,
      srcColorFactor: gpu.BlendFactor.sourceAlpha,
      dstColorFactor: gpu.BlendFactor.oneMinusSourceAlpha,
      srcAlphaFactor: gpu.BlendFactor.one,
      dstAlphaFactor: gpu.BlendFactor.oneMinusSourceAlpha,
      colorBlendOp: gpu.BlendOperation.add,
      alphaBlendOp: gpu.BlendOperation.add,
      windingOrder: gpu.WindingOrder.counterClockwise,
      cullMode: gpu.CullMode.none,
    );

    uniforms = GridUniforms(vertexShader: pipelineKey.vertShader, fragmentShader: pipelineKey.fragShader);

    uniforms!.scale = 0.1;
    uniforms!.setResolution(1000,1000);
    uniforms!.majorLineSpacingMM = 25;
    uniforms!.minorLineSpacingMM = 5;
    uniforms!.majorLineThickness = 0.25;
    uniforms!.minorLineThickness = 0.125;
    uniforms!.mmLineThickness    = 0.025;
    uniforms!.majorLineColor = Colors.red;
    uniforms!.minorLineColor = Colors.blue;
    uniforms!.mmLineColor  = Colors.grey;

    navigationDelegate?.updateSceneMatrices(force: true);
  }

  @override
  void dispose() {}

  void drawVBO(gpu.RenderPass renderPass, Matrix4 pMatrix, Matrix4 mvMatrix) {
    pipelineCache.activate(pipelineKey,renderPass,v3t2Layout);

    exampleVbo.bind(renderPass);

    uniforms!.mvMatrix = mvMatrix.clone();
    uniforms!.pMatrix = pMatrix.clone();
    uniforms!.bind(renderPass);

    exampleVbo.drawTriangles(renderPass);
  }

  @override
  void drawScene(gpu.RenderPass renderPass) async {
    // Scissor and viewport
    setupScissor(renderPass);
    drawVBO(renderPass,pMatrix, mvMatrix);
  }
}