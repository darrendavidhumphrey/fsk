import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';
import 'package:fsk/fsk.dart';
import 'frame_data.dart';

abstract class FrameNode with LoggableClass {
  final FrameObjectData data;
  final FrameScene parentScene;
  bool visible = true;
  late final gpu.Shader? vertexShader;
  late final gpu.Shader? fragmentShader;
  FrameNode(this.parentScene,this.data);

  void setupShader({required String defaultShader}) {
    String shaderName;
    shaderName = (data.shader != null) ? data.shader! : defaultShader;

    vertexShader = FSK().shaderLibrary['${shaderName}Vertex'];
    fragmentShader = FSK().shaderLibrary['${shaderName}Fragment'];

    if (vertexShader == null || fragmentShader == null) {
      throw Exception('Required shader variants for $shaderName were missing from the bundle.');
    }
  }

  void draw(gpu.RenderPass renderPass,Matrix4 pMatrix, MatrixStack mvStack);
  void dispose();
}

class FrameGroupNode extends FrameNode {
  final List<FrameNode> children = [];

  FrameGroupNode(super.parentScene,GroupData super.data);

  @override
  void draw(gpu.RenderPass renderPass,Matrix4 pMatrix, MatrixStack mvStack) {
    //print("Draw group ${data.id}, visible=$visible");
    if (!visible) return;

    final groupData = data as GroupData;
    mvStack.withPushed(() {
      mvStack.current.translateByVector3(groupData.anchor);
      for (var child in children) {
        child.draw(renderPass,pMatrix, mvStack);
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

abstract class FrameObjectNode<T extends FskRenderableObject> extends FrameNode {
  T? object;

  FrameObjectNode(super.parentScene,super.data) {
    visible = data.visible;
  }

  @override
  void draw(gpu.RenderPass renderPass,Matrix4 pMatrix, MatrixStack mvStack) {
    //print("Draw FrameObjectNode ${data.id}, visible=$visible, isObjectNull = ${object == null}");
    if (!visible || object == null) return;

    object?.draw(renderPass,pMatrix, mvStack.current);
  }

  @override
  void dispose() {
  }
}

class FrameQuadNode extends FrameObjectNode<FskQuad> {

  FrameQuadNode(super.parentScene, super.data) {
    final quadData = data as QuadData;

    const double z = 0.01;
    final rect = Quad.points(
      Vector3(quadData.screenRect.left, quadData.screenRect.top, z),
      Vector3(quadData.screenRect.right, quadData.screenRect.top, z),
      Vector3(quadData.screenRect.right, quadData.screenRect.bottom, z),
      Vector3(quadData.screenRect.left, quadData.screenRect.bottom, z),
    );

    object = FskQuad(parentScene,rect, quadData.textureRect, quadData.texture);
    object?.premultiplyAlpha = quadData.premultiplyAlpha;


    // TODO: Send in shader here and uniform class and string list of params
  }
}

class FrameTextNode extends FrameObjectNode<FskBitmapText> {
  FrameTextNode(super.parentScene, super.data) {
    final textData = data as FrameTextData;
    var font = BitmapFontManager().getFont(textData.font);

    if (font == null) {
      font = BitmapFontManager().defaultFont;
      logWarning("Font not found for ${data.id}, using default font");
    }
    final refBox = ReferenceBox(
      Vector3(textData.screenRect.left, textData.screenRect.bottom, 0),
      Vector3(textData.screenRect.width, 0, 0),
      Vector3(0, textData.screenRect.height, 0),
      Vector3(0, 0, 1),
    );

    // Parse the hex string or default to solid white Vector4(1.0, 1.0, 1.0, 1.0)
    final textColorVector = parseHexColor(textData.textColor);

    object = FskBitmapText(parentScene,font, textData.text, refBox,
        textColor: textColorVector,horizontalJustification:  textData.hJustify,
        verticalJustification: textData.vJustify,maxLen:textData.maxLen);

    // TODO: Send in shader here and uniform class and string list of params
  }
}
