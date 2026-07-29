import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

class CheckerBoardScene extends FskScene {

  FskVertexBuffer exampleVbo = FskVertexBuffer();
  CheckerBoardUniforms? uniforms;
  late PipelineKey pipelineKey;

  final Size contentSize = Size(500, 500);
  CheckerBoardScene({super.navigationDelegate}) {
    init();
  }

  void init() {
    VboFiller.makeTexturedUnitQuad(
      Rect.fromLTWH(
        -contentSize.width / 2,
        -contentSize.height / 2,
        contentSize.width,
        contentSize.height,
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

    // Center object in view
    finalMvMatrix = mvMatrix * navigationDelegate?.createBoxFitMatrix(contentSize);

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
