import 'package:flutter/material.dart' show Colors;
import '../bitmap_fonts/bitmap_font.dart';
import '../skins/skin_scene_parser.dart';
import '../skins/skin_data.dart';
import 'fsk_text_alignment.dart';
import 'fsk_base_text.dart';

/// A class that manages the geometry and rendering for a single line of text
/// using a [BitmapFont].
class FskBitmapText extends FskBaseText {
  FskBitmapText(
    super.id,
    super.parentScene,
    super.refBox, {
    required super.font,
    required super.text,
    super.textColor = Colors.white,
    super.verticalJustification = TextVerticalJustification.bottom,
    super.horizontalJustification = TextHorizontalJustification.left,
    super.maxLen,
    super.scaleToFit = false,
    super.shaderMaterial,
    super.depthTestEnabled = false,
    super.depthWriteEnabled = false,
  });

  FskBitmapText.fromData(
    super.id,
    super.parentScene,
    super.refBox,
    super.textData, {
    super.shaderMaterial,
  }) : super.fromData();

  static void registerWithFactories() {
    SkinObjectDataFactory.register('text', (node, anchors, parseObject) {
      final String? shaderName = node.getAttribute('shader');
      final Map<String, String> shaderParamsMap =
          SkinSceneParser.parseShaderParams(node.getAttribute('shaderParams'));
      final String rawHJustify = node.getAttribute('hJustify') ?? 'left';
      final String rawVJustify = node.getAttribute('vJustify') ?? 'top';

      final hJustification = TextHorizontalJustification.fromString(
        rawHJustify,
        defaultValue: TextHorizontalJustification.left,
      );
      final vJustification = TextVerticalJustification.fromString(
        rawVJustify,
        defaultValue: TextVerticalJustification.top,
      );

      return SkinTextData(
        id: node.getAttribute('id')!,
        visible: SkinSceneParser.isVisible(node),
        font: node.getAttribute('font')!,
        text: node.getAttribute('text')!,
        screenRect: SkinSceneParser.parseRect(node.getAttribute('screenRect')!),
        hJustify: hJustification,
        vJustify: vJustification,
        maxLen: int.tryParse(node.getAttribute('maxLen') ?? ''),
        scaleToFit: node.getAttribute('scaleToFit') == 'true',
        textColor: node.getAttribute('textColor'),
        shader: shaderName,
        shaderParams: shaderParamsMap,
      );
    });

    FskSceneObjectFactory.register(SkinTextData, (scene, data, createNode) {
      final textData = data as SkinTextData;

      final refBox = SkinObjectData.screenRectToRefBox(textData.screenRect);
      return FskBitmapText.fromData(textData.id, scene, refBox, textData);
    });
  }
}
