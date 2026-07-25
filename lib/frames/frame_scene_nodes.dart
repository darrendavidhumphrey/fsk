import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';
import 'package:fsk/fsk.dart';
import 'frame_data.dart';

abstract class FrameNode with LoggableClass {
  final FrameObjectData data;
  bool visible = true;
  late final gpu.Shader? vertexShader;
  late final gpu.Shader? fragmentShader;
  FrameNode(this.data);

  void setupShader({required String defaultShader}) {
    String shaderName;
    shaderName = (data.shader != null) ? data.shader! : defaultShader;

    vertexShader = FSK().shaderLibrary['${shaderName}Vertex'];
    fragmentShader = FSK().shaderLibrary['${shaderName}Fragment'];

    if (vertexShader == null || fragmentShader == null) {
      throw Exception('Required shader variants for $shaderName were missing from the bundle.');
    }
  }

  void init();
  void draw(gpu.RenderPass renderPass,Matrix4 pMatrix, MatrixStack mvStack);
  void dispose();
}

class FrameGroupNode extends FrameNode {
  final List<FrameNode> children = [];

  FrameGroupNode(GroupData super.data);

  @override
  void init() {
    visible = data.visible;
    for (var child in children) {
      child.init();
    }
  }

  @override
  void draw(gpu.RenderPass renderPass,Matrix4 pMatrix, MatrixStack mvStack) {
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

  FrameObjectNode(super.data);

  @override
  void draw(gpu.RenderPass renderPass,Matrix4 pMatrix, MatrixStack mvStack) {
    if (!visible || object == null) return;

    object?.rebuild();
    object?.drawSetup( renderPass,pMatrix, mvStack.current);
    object?.draw(renderPass);
  }

  @override
  void init() {
    visible = data.visible;
  }

  @override
  void dispose() {
    object?.dispose();
  }
}

class FrameQuadNode extends FrameObjectNode<FskQuad> {
  FrameQuadNode(QuadData super.data);

  @override
  void init() {
    super.init();
    final quadData = data as QuadData;

    final rect = Quad.points(
      Vector3(quadData.screenRect.left, quadData.screenRect.top, 0),
      Vector3(quadData.screenRect.right, quadData.screenRect.top, 0),
      Vector3(quadData.screenRect.right, quadData.screenRect.bottom, 0),
      Vector3(quadData.screenRect.left, quadData.screenRect.bottom, 0),
    );

    object = FskQuad(rect, quadData.textureRect, quadData.texture);

    // TODO: Make a define for the default shader name
    if (quadData.shader != null) {
      setupShader(defaultShader:"SimpleShader");
      object!.setShader(vertexShader, fragmentShader);
    }

    object!.init();
    object!.initShaderParams(data.shaderParams);
  }
}

class FrameTextNode extends FrameObjectNode<FskBitmapText> {
  FrameTextNode(FrameTextData super.data);

  @override
  void init() {
    super.init();
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

    object = FskBitmapText(font, textData.text, refBox,
        textColor: textColorVector,horizontalJustification:  textData.hJustify,
        verticalJustification: textData.vJustify,maxLen:textData.maxLen);


    // TODO: Make a define for the default shader name
    if (textData.shader != null) {
      setupShader(defaultShader:"SimpleShader");
      object!.setShader(vertexShader, fragmentShader);
    }

    object!.init();
    object!.initShaderParams(data.shaderParams);
  }
}
