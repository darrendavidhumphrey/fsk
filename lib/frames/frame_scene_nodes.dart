import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsg/vbo_filler.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:fsg/fsg.dart';
import 'frame_data.dart';
import '../matrix_stack.dart';

abstract class FrameNode {
  final SceneObject data;
  bool visible = true;

  FrameNode(this.data);

  void init(GlStateManager gls);
  void draw(GlStateManager gls, Matrix4 pMatrix, MatrixStack mvStack);
  void dispose();
}

class FrameGroupNode extends FrameNode {
  final List<FrameNode> children = [];

  FrameGroupNode(GroupData super.data);

  @override
  void init(GlStateManager gls) {
    for (var child in children) {
      child.init(gls);
    }
  }

  @override
  void draw(GlStateManager gls, Matrix4 pMatrix, MatrixStack mvStack) {
    if (!visible) return;
    final groupData = data as GroupData;
    mvStack.withPushed(() {
      mvStack.current.translate(groupData.anchor);
      for (var child in children) {
        child.draw(gls, pMatrix, mvStack);
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

class FrameQuadNode extends FrameNode {
  VertexBuffer? vbo;
  WebGLTexture? texture;

  FrameQuadNode(QuadData super.data);

  @override
  void init(GlStateManager gls) {
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
  void draw(GlStateManager gls, Matrix4 pMatrix, MatrixStack mvStack) {
    if (!visible || vbo == null || texture == null) return;

    // TODO: Bind the right shader
    final shader = FSG().shaders.getShader<GlslShader>();
 // TODO:   shader.use();
    ShaderList.setMatrixUniforms(shader, pMatrix, mvStack.current);

    QuadData quadData = data as QuadData;

    if (quadData.premultiplyAlpha) {
      gls.blendFuncSeparate(WebGL.ONE, WebGL.ONE_MINUS_SRC_ALPHA,WebGL.ONE, WebGL.ONE_MINUS_SRC_ALPHA);
    } else {
      gls.blendFuncSeparate(WebGL.SRC_ALPHA, WebGL.ONE_MINUS_SRC_ALPHA,WebGL.SRC_ALPHA, WebGL.ONE_MINUS_SRC_ALPHA);
    }

    gls.activeTexture(WebGL.TEXTURE0);
    gls.bindTexture(WebGL.TEXTURE_2D, texture);

   // TODO:  gls.setUniform1i(shader.uniforms[ShaderList.uSampler]!, 0);

    // TODO:  vbo!.draw(shader);
  }

  @override
  void dispose() {
    vbo?.dispose();
  }
}

class FrameTextNode extends FrameNode {
  BitmapText? bitmapText;

  FrameTextNode(TextData super.data);

  @override
  void init(GlStateManager gls) {
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
  void draw(GlStateManager gls, Matrix4 pMatrix, MatrixStack mvStack) {
    if (!visible || bitmapText == null) return;
    
    bitmapText!.rebuild(gls);
    
    final shader = FSG().shaders.getShader<GlslShader>();
    // TODO: shader.use();
    ShaderList.setMatrixUniforms(shader, pMatrix, mvStack.current);

    gls.activeTexture(WebGL.TEXTURE0);
 // TODO:    gls.bindTexture(WebGL.TEXTURE_2D, bitmapText!.font.fontTexture);
   //TODO:  gls.setUniform1i(shader.uniforms[ShaderList.uSampler]!, 0);

    // TODO:  bitmapText!.vbo?.draw(shader);
  }

  @override
  void dispose() {
    bitmapText?.dispose();
  }
}
