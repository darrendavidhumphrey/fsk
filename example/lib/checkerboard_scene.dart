import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsg/fsg.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

class CheckerBoardScene extends Scene {

  CheckerBoardScene() {
    exampleVbo.makeTexturedUnitQuad(
      Rect.fromLTWH(-quadExtents.width/2, -quadExtents.height/2, quadExtents.width, quadExtents.height),
      0.1,
    );
  }

  VertexBuffer exampleVbo = VertexBuffer.v3t2();
  CheckerBoardShader? shader;

  final Size quadExtents = Size(500, 500);

  final Color color1 = Colors.red;
  final Color color2 = Colors.yellow;

  @override
  void init(RenderingContext gl) {
    super.init(gl);
    exampleVbo.init(gl);
    exampleVbo.uploadData();
  }

  @override
  void dispose() {}


  void drawVBO(Matrix4 pMatrix, Matrix4 mvMatrix) {
    shader ??= FSG().shaders.getShaderByType<CheckerBoardShader>("checkerBoard");
    gl.useProgram(shader!.program);
    ShaderList.setMatrixUniforms(shader!, pMatrix, mvMatrix);

    shader!.setPatternColor1(color1);
    shader!.setPatternColor2(color2);
    shader!.setPatternScale(10);

    exampleVbo.bind();
    exampleVbo.drawTriangles();
    exampleVbo.unbind();
  }

  void createViewMatrix() {
    Vector3 up = Vector3(0, 1, 0);
    Vector3 orbitCenter = Vector3(0,0,0);
    Vector3 eyeLocation = Vector3(0,0,-500);

    mvMatrixStack.current = makeViewMatrix(eyeLocation, orbitCenter, up);
    mvMatrix.translateByVector3(orbitCenter);
    mvMatrix.rotateZ(radians(180));
    mvMatrix.rotateY(radians(0));
    mvMatrix.rotateX(radians(45));
    mvMatrix.translateByVector3(-orbitCenter);
  }

  void createProjectionMatrix() {
    final double aspectRatio = viewportSize.width / viewportSize.height;

    setPerspectiveMatrix(
      pMatrix,
      radians(60),
      aspectRatio,
      0.1,
      5000000,
    );

    // Ensure Y Axis is the same regardless of platform
    FSG.normalizeUpAxis(pMatrix);
  }

  @override
  void drawScene() {

    gl.viewport(0, 0, FSG.renderToTextureSize.toInt(), FSG.renderToTextureSize.toInt());
    gl.enable(WebGL.BLEND);
    gl.disable(WebGL.CULL_FACE);
    gl.clearColor(0.0, 1.0, 1.0 , 1.0);
    gl.clear(WebGL.COLOR_BUFFER_BIT | WebGL.DEPTH_BUFFER_BIT);

    createProjectionMatrix();
    createViewMatrix();

    withPushedMatrix( () {
      drawVBO(pMatrix, mvMatrix);
    });

    requestRepaint();
  }
}
