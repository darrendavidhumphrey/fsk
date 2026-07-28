import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';
import 'package:fsk/fsk.dart';
import 'frame_data.dart';

abstract class FrameNode with LoggableClass {
  final FrameObjectData data;
  final FrameScene parentScene;
  bool visible = true;

  FrameNode(this.parentScene, this.data);

  // Before drawing, traverse all nodes and ensure their VBOs are up to date
  // to avoid mucking with the GPU state during the draw traversal
  void rebuildGeometry();

  void draw(
    gpu.RenderPass renderPass,
    gpu.HostBuffer transients,
    Matrix4 pMatrix,
    Matrix4 mvMatrix,
  );
  void dispose();
}

class FrameGroupNode extends FrameNode {
  final List<FrameNode> children = [];

  FrameGroupNode(super.parentScene, GroupData super.data);

  @override
  void rebuildGeometry() {
    for (var child in children) {
      child.rebuildGeometry();
    }
  }

  @override
  void draw(
    gpu.RenderPass renderPass,
    gpu.HostBuffer transients,
    Matrix4 pMatrix,
    Matrix4 mvMatrix,
  ) {
    if (!visible) return;

    final groupData = data as GroupData;

    // Create the child object's local translation matrix
    final Matrix4 localTranslation = Matrix4.identity()
      ..translateByVector3(groupData.anchor);

    assert (!localTranslation.isZero());
    // 4. Pass down the fully computed local-to-world context downward
    for (var child in children) {
      // Clone the incoming matrix to ensure absolute isolation between child branches
      final Matrix4 mvTrans = mvMatrix.clone()..multiply(localTranslation);

      child.draw(renderPass, transients, pMatrix, mvTrans);
    }
  }

  @override
  void dispose() {
    for (var child in children) {
      child.dispose();
    }
  }
}

abstract class FrameObjectNode<T extends FskRenderableObject>
    extends FrameNode {
  T? object;

  FrameObjectNode(super.parentScene, super.data) {
    visible = data.visible;
  }

  @override
  void draw(
    gpu.RenderPass renderPass,
    gpu.HostBuffer transients,
    Matrix4 pMatrix,
    Matrix4 mvMatrix,
  ) {
    //print("Draw FrameObjectNode ${data.id}, visible=$visible, isObjectNull = ${object == null}");
    if (!visible || object == null) return;

    object?.draw(renderPass, transients, pMatrix, mvMatrix);
  }

  @override
  void dispose() {}

  @override
  void rebuildGeometry() {
    object?.rebuildIfNeeded();
    object?.rebuildPipelineIfNeeded();
  }
}

class FrameQuadNode extends FrameObjectNode<FskQuad> {
  FrameQuadNode(super.parentScene, super.data) {
    final quadData = data as QuadData;

    final rect = Quad.points(
      Vector3(0.0, 0.0, 0.0),
      Vector3(quadData.screenRect.width, 0.0, 0.0),
      Vector3(quadData.screenRect.width, quadData.screenRect.height, 0.0),
      Vector3(0.0, quadData.screenRect.height, 0.0),
    );

    object = FskQuad(
        parentScene, rect, quadData.textureRect, quadData.texture,
        id: data.id);
    object?.premultiplyAlpha = quadData.premultiplyAlpha;
    object?.screenRect = quadData.screenRect;
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

    object = FskBitmapText(
      parentScene,
      font,
      textData.text,
      refBox,
      textColor: textColorVector,
      horizontalJustification: textData.hJustify,
      verticalJustification: textData.vJustify,
      maxLen: textData.maxLen,
    );

    // TODO: Send in shader here and uniform class and string list of params
  }
}
