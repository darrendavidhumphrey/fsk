import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsg/vbo_filler.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:fsg/fsg.dart';
import 'game_scene_data.dart';
import 'matrix_stack.dart';

abstract class GameSceneNode {
  final SceneObject data;
  bool visible = true;

  GameSceneNode(this.data);

  void init(RenderingContext gl);
  void draw(RenderingContext gl, Matrix4 pMatrix, MatrixStack mvStack);
  void dispose();
}

class GameGroupNode extends GameSceneNode {
  final List<GameSceneNode> children = [];

  GameGroupNode(GroupData super.data);

  @override
  void init(RenderingContext gl) {
    for (var child in children) {
      child.init(gl);
    }
  }

  @override
  void draw(RenderingContext gl, Matrix4 pMatrix, MatrixStack mvStack) {
    if (!visible) return;
    final groupData = data as GroupData;
    mvStack.withPushed(() {
      mvStack.current.translate(groupData.anchor);
      for (var child in children) {
        child.draw(gl, pMatrix, mvStack);
      }
    });
  }

  @override
  void dispose() {
    for (var child in children) {
      child.dispose();
    }
  }
}

class GameQuadNode extends GameSceneNode {
  VertexBuffer? vbo;
  WebGLTexture? texture;

  GameQuadNode(QuadData super.data);

  @override
  void init(RenderingContext gl) {
    final quadData = data as QuadData;
    vbo = VertexBuffer.v3t2();
    final buffer = vbo!.requestBuffer(6);
    if (buffer != null) {

      final rect = Quad.points(
        Vector3(quadData.screenRect.left, quadData.screenRect.top, 0),
        Vector3(quadData.screenRect.right, quadData.screenRect.top, 0),
        Vector3(quadData.screenRect.right, quadData.screenRect.bottom, 0),
        Vector3(quadData.screenRect.left, quadData.screenRect.bottom, 0),
      );
      VboFiller.makeTexturedQuad(rect, quadData.textureRect ,vbo!);
    }


    // Texture should be loaded by the scene/manager
  }

  @override
  void draw(RenderingContext gl, Matrix4 pMatrix, MatrixStack mvStack) {
    if (!visible || vbo == null || texture == null) return;

    // TODO: Bind the right shader
    final shader = FSG().shaders.getShader<GlslShader>();
 // TODO:   shader.use();
    ShaderList.setMatrixUniforms(shader, pMatrix, mvStack.current);

    gl.activeTexture(WebGL.TEXTURE0);
    gl.bindTexture(WebGL.TEXTURE_2D, texture);

   // TODO:  gls.setUniform1i(shader.uniforms[ShaderList.uSampler]!, 0);

    // TODO:  vbo!.draw(shader);
  }

  @override
  void dispose() {
    vbo?.dispose();
  }
}

class GameTextNode extends GameSceneNode {
  BitmapText? bitmapText;

  GameTextNode(TextData super.data);

  @override
  void init(RenderingContext gl) {
    final textData = data as TextData;
    final font = BitmapFontManager().getFont(textData.font);
    if (font != null) {
      final refBox = ReferenceBox(
        Vector3(textData.screenRect.left, textData.screenRect.top, 0),
        Vector3(textData.screenRect.width, 0, 0),
        Vector3(0, textData.screenRect.height, 0),
        Vector3(0, 0, 1),
      );
      bitmapText = BitmapText(font, textData.text, refBox);
    }
  }

  @override
  void draw(RenderingContext gl, Matrix4 pMatrix, MatrixStack mvStack) {
    if (!visible || bitmapText == null) return;
    
    bitmapText!.rebuild(gl);
    
    final shader = FSG().shaders.getShader<GlslShader>();
    // TODO: shader.use();
    ShaderList.setMatrixUniforms(shader, pMatrix, mvStack.current);

    gl.activeTexture(WebGL.TEXTURE0);
 // TODO:    gls.bindTexture(WebGL.TEXTURE_2D, bitmapText!.font.fontTexture);
   //TODO:  gls.setUniform1i(shader.uniforms[ShaderList.uSampler]!, 0);

    // TODO:  bitmapText!.vbo?.draw(shader);
  }

  @override
  void dispose() {
    bitmapText?.dispose();
  }
}
