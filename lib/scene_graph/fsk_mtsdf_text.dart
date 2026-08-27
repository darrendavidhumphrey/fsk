import 'dart:ui';
import '../bitmap_fonts/texture_font.dart';
import '../gpu/fsk_shader_material.dart';
import '../shaders/base_uniforms.dart';
import '../shaders/mtsdf_text_shader.dart';
import 'fsk_base_text.dart';

/// A class that manages the geometry and rendering for a single line of text
/// using a [TextureFont] with MTSDF (Multi-channel Signed Distance Field) textures.
class FskMtsdfText extends FskBaseText {
  Color _glowColor = const Color(0x00000000);
  double _glowSize = 0.0;

  Color get glowColor => _glowColor;
  set glowColor(Color value) {
    if (_glowColor != value) {
      _glowColor = value;
      parentScene.setNeedsUpdate();
    }
  }

  double get glowSize => _glowSize;
  set glowSize(double value) {
    if (_glowSize != value) {
      _glowSize = value;
      parentScene.setNeedsUpdate();
    }
  }

  bool _debug = false;
  void setDebug(bool value) {
    _debug = value;
    renderer.setDebug(value);
  }

  FskMtsdfText(
    super.id,
    super.parentScene,
    super.refBox, {
    required super.font,
    required super.text,
    super.textColor,
    this._glowColor = const Color(0x00000000),
    this._glowSize = 0.0,
    super.verticalJustification,
    super.horizontalJustification,
    super.maxLen,
    super.scaleToFit,
    FskShaderMaterial? shaderMaterial,
    super.depthTestEnabled,
    super.depthWriteEnabled,
  })  : super(
          shaderMaterial: shaderMaterial ?? FskShaderMaterial.mtsdfText,
        );

  @override
  void updateUniforms(BaseUniforms uniforms) {
    super.updateUniforms(uniforms);
    var u = uniforms as MtsdfTextUniforms;
    u.setTextColor(textColor);
    u.setGlowColor(glowColor);
    u.setGlowSize(glowSize);
  }

}
