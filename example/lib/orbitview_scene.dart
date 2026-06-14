import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsg/fsg.dart';
import 'package:fsg/vbo_filler.dart';

class OrbitViewScene extends Scene {
  OrbitViewScene() {
    // TODO: make cube

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
  }

  VertexBuffer exampleVbo = VertexBuffer.v3t2();
  final Size quadExtents = Size(500, 500);
  CheckerBoardShader? shader;

  @override
  void init(RenderingContext gl) {
    super.init(gl);
    exampleVbo.init(gl);
    exampleVbo.uploadData();
  }

  void drawVBO(Matrix4 pMatrix, Matrix4 mvMatrix) {
    // TODO: Use different shader
    shader ??= FSG().shaders.getShader<CheckerBoardShader>();

    gls.useProgram(shader!.program);
    ShaderList.setMatrixUniforms(shader!, pMatrix, mvMatrix);

    shader!.setPatternScale(4.0);
    shader!.setPatternColor1(Colors.red);
    shader!.setPatternColor2(Colors.blue);

    exampleVbo.bind();
    exampleVbo.drawTriangles();
    exampleVbo.unbind();
  }

  @override
  void drawScene() async {
    super.drawScene();

    gls.setViewport(
      0,
      0,
      FSG.renderToTextureSize.toInt(),
      FSG.renderToTextureSize.toInt(),
    );
    gls.activeTexture(WebGL.TEXTURE0);
    gls.setTexturingEnabled(false);

    gls.setBlend(true);
    gls.setCullFace(false);
    gls.clearColor(0, 1, 1, 1);
    gls.setDepthTest(false);
    gls.setDepthMask(false);

    gls.depthFunc(WebGL.LESS);
    gls.blendFuncSeparate(
      WebGL.SRC_ALPHA,
      WebGL.ONE_MINUS_SRC_ALPHA,
      WebGL.ONE,
      WebGL.ONE_MINUS_SRC_ALPHA,
    );
    gl.clear(WebGL.COLOR_BUFFER_BIT | WebGL.DEPTH_BUFFER_BIT);
    withPushedMatrix(() {
      drawVBO(pMatrix, mvMatrix);
    });

    requestRepaint();
  }
}
