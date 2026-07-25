import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

class CheckerBoardScene extends FskScene {
  CheckerBoardScene({super.navigationDelegate}) {
    print("CheckerBoardScene constructor");
  }

  VertexBuffer exampleVbo = VertexBuffer.v3t2();
  gpu.Shader? vertexShader;
  gpu.Shader? fragmentShader;

  final Size quadExtents = Size(500, 500);

  @override
  void init() {
    super.init();

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
    vertexShader = FSK().shaderLibrary['CheckerBoardVertex']!;
    fragmentShader = FSK().shaderLibrary['CheckerBoardFragment']!;
    assert(vertexShader != null);
    assert(fragmentShader != null);
  }

  @override
  void dispose() {}

  void drawVBO(gpu.RenderPass renderPass, Matrix4 pMatrix, Matrix4 mvMatrix) {

    exampleVbo.bind(renderPass);
    CheckerBoardUniforms.setUniforms(
      renderPass: renderPass,
      vertexShader: vertexShader!,
      fragmentShader: fragmentShader!,
      pMatrix: pMatrix,
      mvMatrix: mvMatrix,
      patternColor1: Colors.red,
      patternColor2: Colors.blue,
      useTexture: false,
      textureMix: 0,
      patternScale: 10,
    );

    exampleVbo.drawTriangles(renderPass);
  }

  @override
  void drawScene(gpu.RenderPass renderPass, Size viewportSize) async {

    // Call base class to setup scissor and viewport
    super.drawScene(renderPass, viewportSize);

    renderPass.setCullMode(gpu.CullMode.none);
    renderPass.setDepthWriteEnable(false); // Disables depth masking (setDepthMask false)
    renderPass.setDepthCompareOperation(gpu.CompareFunction.always);
    renderPass.setColorBlendEnable(true); // Enables alpha blending
    renderPass.setColorBlendEquation(
      gpu.ColorBlendEquation(
        colorBlendOperation: gpu.BlendOperation.add,
        sourceColorBlendFactor: gpu.BlendFactor.sourceAlpha,               // WebGL.SRC_ALPHA
        destinationColorBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha,  // WebGL.ONE_MINUS_SRC_ALPHA

        alphaBlendOperation: gpu.BlendOperation.add,
        sourceAlphaBlendFactor: gpu.BlendFactor.one,                       // WebGL.ONE
        destinationAlphaBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha, // WebGL.ONE_MINUS_SRC_ALPHA
      ),
    );

    withPushedMatrix(() {
      drawVBO(renderPass,pMatrix, mvMatrix);
    });

    requestRepaint();
  }
}
