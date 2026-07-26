import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'base_uniforms.dart';

class TextShaderUniforms extends BaseUniforms {
  // --- Keys & Uniform Names ---
  static const String _kTextColorKey = 'textColor';
  static const String _kSamplerUniformName = 'uSampler';

  // --- Defaults & Layout Rules ---
  static const Color _kDefaultTextColor = Color(0xFFFFFFFF);
  static const int _kFragmentDataFloatCount = 4;
  static const int _kColorBufferOffset = 0;

  gpu.Texture? _texture;

  TextShaderUniforms({super.vertexShader, super.fragmentShader}) {
    // Establish initialization values inside the string data store
    this[_kTextColorKey] = _kDefaultTextColor;
  }

  // --- Type-Safe Public Setters ---
  set textColor(Color val) => this[_kTextColorKey] = val;
  set texture(gpu.Texture? val) => _texture = val;

  /// Serializes the text configuration data into a precise std140 block map.
  /// layout(std140) vec4 uTextColor maps to exactly 4 floats (16 bytes).
  @override
  Float32List serializeFragmentData() {
    final Float32List fragmentData = Float32List(_kFragmentDataFloatCount);

    // Pull the color configuration and serialize it starting at the designated offset
    packColor(fragmentData, _kColorBufferOffset, this[_kTextColorKey] as Color);

    return fragmentData;
  }

  /// Extends the base bind pass to handle the correct UniformSlot texture loop.
  @override
  void bind(gpu.RenderPass renderPass) {
    // 1. Fire the base routine to bind Vertex matrices and the TextColorBlock uniform array
    super.bind(renderPass);

    if (_texture != null && fragmentShader != null) {
      final gpu.UniformSlot textureSlot = fragmentShader!.getUniformSlot(_kSamplerUniformName);
      renderPass.bindTexture(textureSlot, _texture!);
    }
  }
}
