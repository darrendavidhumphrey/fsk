import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

class CheckerBoardScene extends FskScene {

  VertexBuffer exampleVbo = VertexBuffer();
  CheckerBoardUniforms? uniforms;
  late PipelineKey pipelineKey;

  CheckerBoardScene({super.navigationDelegate}) {
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

    exampleVbo.uploadData(this);

    // Create a pipeline key for this shader and associated settings
    pipelineKey = PipelineKey(
      vertShaderName: "CheckerBoardVertex",
      fragShaderName: "CheckerBoardFragment",
      layoutName: "CheckerBoardLayout",
      depthTestEnabled: false,
      depthWriteEnabled: false,
      depthCompareOperation: gpu.CompareFunction.less,
      texturingEnabled: false,
      srcColorFactor: gpu.BlendFactor.sourceAlpha,
      dstColorFactor: gpu.BlendFactor.oneMinusSourceAlpha,
      srcAlphaFactor: gpu.BlendFactor.one,
      dstAlphaFactor: gpu.BlendFactor.oneMinusSourceAlpha,
      colorBlendOp: gpu.BlendOperation.add,
      alphaBlendOp: gpu.BlendOperation.add,
      windingOrder: gpu.WindingOrder.counterClockwise,
      cullMode: gpu.CullMode.none,
    );

    uniforms = CheckerBoardUniforms(vertexShader: pipelineKey.vertShader, fragmentShader: pipelineKey.fragShader);

    navigationDelegate?.updateSceneMatrices(force: true);
  }

  @override
  void dispose() {}

  void drawVBO(gpu.RenderPass renderPass,gpu.HostBuffer transients, Matrix4 pMatrix, Matrix4 mvMatrix) {
    pipelineCache.activate(pipelineKey,renderPass,v3t2Layout);
    exampleVbo.bind(renderPass);

    Matrix4 finalMvMatrix;

    // Center object in view when using OrthoViewDelegate
    if (navigationDelegate is OrthoViewDelegate) {
      finalMvMatrix = mvMatrix.clone()
        ..translateByVector3(Vector3(viewportSize.width / 2, viewportSize.height / 2, 0.0));
    } else {
      finalMvMatrix = mvMatrix.clone();
    }

    uniforms!.patternColor1 = Colors.red;
    uniforms!.patternColor2 = Colors.green;
    uniforms!.useTexture = false;
    uniforms!.textureMix = 0;
    uniforms!.patternScale = 50;
    uniforms!.mvMatrix =  finalMvMatrix;
    uniforms!.pMatrix = pMatrix.clone();
    uniforms!.bind(renderPass,transients);

    exampleVbo.drawTriangles(renderPass);
  }

  @override
  void drawScene(gpu.RenderPass renderPass,gpu.HostBuffer transients) {
    // Scissor and viewport
    setupScissor(renderPass);
    drawVBO(renderPass,transients,pMatrix, mvMatrix);

  }
}
