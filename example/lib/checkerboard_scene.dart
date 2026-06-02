import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsg/fsg.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

class CheckerBoardScene extends Scene {
  CheckerBoardScene();

  late VertexBuffer exampleVbo;
  final Size quadExtents = Size(500, 500);

  final Color color1 = Colors.red;
  final Color color2 = Colors.yellow;

  @override
  void init(RenderingContext gl) {
    super.init(gl);
    exampleVbo = VertexBuffer.v3t2(gl);

    exampleVbo.makeTexturedUnitQuad(
      Rect.fromLTWH(-quadExtents.width/2, -quadExtents.height/2, quadExtents.width, quadExtents.height),
      0.1,
    );

    print("CheckerboardScene init");

    gl.checkError("CheckerboardScene Init");
  }

  @override
  void dispose() {}

  void drawVBO(Matrix4 pMatrix, Matrix4 mvMatrix) {
    var shader = FSG().shaders.getShader("checkerBoard");
    gl.useProgram(shader.program);
    ShaderList.setMatrixUniforms(shader, pMatrix, mvMatrix);
    gl.enable(WebGL.DEPTH_TEST);

    shader.setPatternColor1(color1);
    shader.setPatternColor2(color2);
    shader.setPatternScale(50);

    exampleVbo.bind();
    exampleVbo.drawTriangles();
    exampleVbo.unbind();
    gl.checkError("CheckerboardScene drawvbo");
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

    if (kIsWeb) {
      // Multiply the Y scale component (row 1, column 1) by -1
      pMatrix.scale(1.0, -1.0, 1.0);
    }
  }

  @override
  void drawScene() {
    //print("CheckerboardScene drawScene()");
    gl.clearColor(1.0,0.0, 1.0, 1.0);
    gl.checkError("clear color");


    gl.clear(WebGL.COLOR_BUFFER_BIT | WebGL.DEPTH_BUFFER_BIT);
    gl.enable(WebGL.DEPTH_TEST);
    gl.enable(WebGL.BLEND);
    gl.disable(WebGL.CULL_FACE);
    gl.depthFunc(WebGL.LESS);

    createProjectionMatrix();
    createViewMatrix();

    withPushedMatrix( () {
      drawVBO(pMatrix, mvMatrix);
    });

    gl.finish();
    gl.flush();
  }
}
