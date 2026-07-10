import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsk/fsk.dart';
import 'package:fsk/vbo_filler.dart';

class OrbitViewScene extends FskScene {
  OrbitViewScene({super.navigationDelegate}) {

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
  GridShader? shader;

  @override
  void init(RenderingContext gl) {
    super.init(gl);
    exampleVbo.init(gls);
    exampleVbo.uploadData();
  }

  void drawVBO(Matrix4 pMatrix, Matrix4 mvMatrix) {
    shader ??= FSK().shaders.getShader<GridShader>();

    gls.useProgram(shader!.program);
    ShaderList.setMatrixUniforms(shader!, pMatrix, mvMatrix);

    shader!.setResolutionMM(250,250);
    shader!.setScale(0.1);
    shader!.setMajorLineSpacingMM(25);
    shader!.setMinorLineSpacingMM(5);
    shader!.setMajorLineThickness(1);
    shader!.setMinorLineThickness(0.25);
    shader!.setMmLineThickness(0.025);
    shader!.setMajorLineColor(Colors.red);
    shader!.setMinorLineColor(Colors.blue);
    shader!.setMmLineColor(Colors.green);
    exampleVbo.bind();
    exampleVbo.drawTriangles();
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
    gl.clear(WebGL.COLOR_BUFFER_BIT | WebGL.DEPTH_BUFFER_BIT);
    withPushedMatrix(() {
      drawVBO(pMatrix, mvMatrix);
    });

    requestRepaint();
  }
}
