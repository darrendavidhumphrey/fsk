import 'dart:typed_data';
import 'dart:ui';
import 'base_uniforms.dart';

class TextShaderUniforms extends BaseUniforms {
  // --- Keys & Uniform Names ---
  static const String _kTextColorKey = 'textColor';

  // --- Defaults & Layout Rules ---
  static const Color _kDefaultTextColor = Color(0xFFFFFFFF);
  static const int _kFragmentDataFloatCount = 4;
  static const int _kColorBufferOffset = 0;

  @override
  bool get hasSampler => true;

  @override
  String get samplerUniformName => 'uTextSampler';
  @override
  String get fragmentBlockName => 'TextUniformBlock';

  TextShaderUniforms({super.vertexShader, super.fragmentShader}) {
    // Establish initialization values inside the string data store
    this[_kTextColorKey] = _kDefaultTextColor;
  }

  // --- Type-Safe Public Setters ---
  set textColor(Color val) => this[_kTextColorKey] = val;

  /// Serializes the text configuration data into a precise std140 block map.
  /// layout(std140) vec4 uTextColor maps to exactly 4 floats (16 bytes).
  @override
  Float32List serializeFragmentData() {
    final Float32List fragmentData = Float32List(_kFragmentDataFloatCount);

    // Pull the color configuration and serialize it starting at the designated offset
    packColor(fragmentData, _kColorBufferOffset, this[_kTextColorKey] as Color);

    return fragmentData;
  }
}
