import 'dart:typed_data';
import 'dart:ui';
import 'base_uniforms.dart';

class SimpleTextureUniforms extends BaseUniforms {
  // --- Dictionary Key Constants ---
  static const String _kModulateColorKey = 'modulateColor';
  @override
  String get fragmentBlockName => 'SimpleTextureUniformBlock';

  // --- Default Layout Value Constants ---
  static const Color _kDefaultModulateColor = Color(0xFFFFFFFF);

  // --- Buffer Structure Allocation Constants ---
  static const int _kFragmentDataFloatCount = 4;

  SimpleTextureUniforms({super.vertexShader, super.fragmentShader}) {
    // Establish initialization values inside the string data store
    this[_kModulateColorKey] = _kDefaultModulateColor;
  }

  @override
  bool get hasSampler => true;
  @override
  String get samplerUniformName => 'uSampler';

  // --- Type-Safe Public Methods ---

  /// Type-safe method to update the modulation color configuration payload.
  void setModulateColor(Color color) {
    this[_kModulateColorKey] = color;
  }

  @override
  Float32List serializeFragmentData() {
    final Float32List fragmentData = Float32List(_kFragmentDataFloatCount);

    // Pack modulateColor into the first 4 floats (16 bytes)
    packColor(fragmentData, 0, this[_kModulateColorKey] as Color);

    return fragmentData;
  }
}
