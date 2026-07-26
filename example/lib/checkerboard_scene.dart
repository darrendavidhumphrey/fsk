import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:fsk/gpu/gpu_pipeline_key.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

class CheckerBoardScene extends FskScene {

  VertexBuffer exampleVbo = VertexBuffer();
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

    exampleVbo.uploadData();

    // Create a pipeline key for this shader and associated settings
    pipelineKey = PipelineKey(
      vertShaderName: "CheckerBoardVertex",
      fragShaderName: "CheckerBoardFragment",
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
  }

  @override
  void dispose() {}

  void drawVBO(gpu.RenderPass renderPass, Matrix4 pMatrix, Matrix4 mvMatrix) {

    var pipeline = pipelineCache.activate(pipelineKey,renderPass,v3t2Layout);

    exampleVbo.bind(renderPass);
    CheckerBoardUniforms.setUniforms(
      renderPass: renderPass,
      vertexShader: pipeline.vertexShader,
      fragmentShader: pipeline.fragmentShader,
      pMatrix: pMatrix,
      mvMatrix: mvMatrix,
      patternColor1: Colors.red,
      patternColor2: Colors.green,
      useTexture: false,
      textureMix: 0,
      patternScale: 5,
    );

    exampleVbo.drawTriangles(renderPass);
  }

  @override
  void drawScene(gpu.RenderPass renderPass, Size viewportSize) async {

    // Call base class to setup scissor and viewport
    super.drawScene(renderPass, viewportSize);

    withPushedMatrix(() {
      drawVBO(renderPass,pMatrix, mvMatrix);
    });
  }
}
