import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsg/fsg.dart';

class OrbitViewScene extends Scene {
  OrbitViewScene();

  late VertexBuffer exampleVbo;
  final Size quadExtents = Size(500, 500);


  @override
  void init(RenderingContext gl) {
    super.init(gl);
    exampleVbo = VertexBuffer.v3t2(gl);

    // TODO: make cube
    exampleVbo.makeTexturedUnitQuad(
      Rect.fromLTWH(-quadExtents.width/2, -quadExtents.height/2, quadExtents.width, quadExtents.height),
      0.1,
    );
  }

  @override
  void dispose() {}

  void drawVBO(Matrix4 pMatrix, Matrix4 mvMatrix) {

    // TODO: Use different shader
    CheckerBoardShader shader = FSG().shaders.getShader("checkerBoard");
    gl.useProgram(shader.program);
    ShaderList.setMatrixUniforms(shader, pMatrix, mvMatrix);
    gl.enable(WebGL.DEPTH_TEST);
    shader.setPatternScale(4.0);
    shader.setPatternColor1(Colors.red);
    shader.setPatternColor2(Colors.blue);

    exampleVbo.bind();
    exampleVbo.drawTriangles();
    exampleVbo.unbind();
  }

  @override
  void drawScene() {
    gl.clearColor(1.0, 1.0, 1.0, 1.0);

    gl.clear(WebGL.COLOR_BUFFER_BIT | WebGL.DEPTH_BUFFER_BIT);
    gl.enable(WebGL.DEPTH_TEST);
    gl.enable(WebGL.BLEND);
    gl.disable(WebGL.CULL_FACE);
    gl.depthFunc(WebGL.LESS);

    withPushedMatrix( () {
      drawVBO(pMatrix, mvMatrix);
    });

    gl.finish();
  }
}