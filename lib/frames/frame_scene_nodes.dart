import 'package:fsg/scene_graph/fsk_quad.dart';
import 'package:fsg/scene_graph/fsk_scene_object.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:fsg/fsk.dart';
import 'frame_data.dart';
import '../matrix_stack.dart';

abstract class FrameNode with LoggableClass {
  final FrameObjectData data;
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
      mvStack.current.translateByVector3(groupData.anchor);
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

abstract class FrameObjectNode<T extends FskSceneObject> extends FrameNode {
  T? object;

  FrameObjectNode(super.data);

  @override
  void draw(GlStateManager gls, Matrix4 pMatrix, MatrixStack mvStack) {
    if (!visible || object == null) return;

    object?.rebuild(gls);
    object?.drawSetup(gls, pMatrix, mvStack.current);
    object?.draw(gls);
  }

  @override
  void dispose() {
    object?.dispose();
  }
}

class FrameQuadNode extends FrameObjectNode<FskQuad> {
  FrameQuadNode(QuadData super.data);

  @override
  void init(GlStateManager gls) {
    final quadData = data as QuadData;

    final rect = Quad.points(
      Vector3(quadData.screenRect.left, quadData.screenRect.top, 0),
      Vector3(quadData.screenRect.right, quadData.screenRect.top, 0),
      Vector3(quadData.screenRect.right, quadData.screenRect.bottom, 0),
      Vector3(quadData.screenRect.left, quadData.screenRect.bottom, 0),
    );

    object = FskQuad(rect, quadData.textureRect, quadData.texture);
    object!.init(gls);
  }
}

class FrameTextNode extends FrameObjectNode<FskBitmapText> {
  FrameTextNode(FrameTextData super.data);

  @override
  void init(GlStateManager gls) {
    final textData = data as FrameTextData;
    var font = BitmapFontManager().getFont(textData.font);

    if (font == null) {
      font = BitmapFontManager().defaultFont;
      logWarning("Font not found for ${data.id}, using default font");
    }
    final refBox = ReferenceBox(
      Vector3(textData.screenRect.left, textData.screenRect.top, 0),
      Vector3(textData.screenRect.width, 0, 0),
      Vector3(0, textData.screenRect.height, 0),
      Vector3(0, 0, 1),
    );
    object = FskBitmapText(font, textData.text, refBox);
    object!.init(gls);
  }
}
