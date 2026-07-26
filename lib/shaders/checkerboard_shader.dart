import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'base_uniforms.dart';

class CheckerBoardUniforms extends BaseUniforms {
  // --- Dictionary Key Constants ---
  static const String _kPatternColor1Key = 'patternColor1';
  static const String _kPatternColor2Key = 'patternColor2';
  static const String _kUseTextureKey = 'useTexture';
  static const String _kTextureMixKey = 'textureMix';
  static const String _kPatternScaleKey = 'patternScale';
  static const String _kSamplerUniformName = 'uSampler';

  // --- Default Layout Value Constants ---
  static const Color _kDefaultPatternColor1 = Color(0xFFFFFFFF);
  static const Color _kDefaultPatternColor2 = Color(0xFF000000);
  static const bool _kDefaultUseTexture = false;
  static const double _kDefaultTextureMix = 0.0;
  static const double _kDefaultPatternScale = 1.0;

  // --- Buffer Structure Allocation Constants ---
  static const int _kFragmentDataFloatCount = 12;
  static const int _kUseTextureBufferIndex = 8;
  static const int _kTextureMixBufferIndex = 9;
  static const int _kPatternScaleBufferIndex = 10;
  static const int _kPaddingBufferIndex = 11;

  static const double _kBooleanTrueValue = 1.0;
  static const double _kBooleanFalseValue = 0.0;
  static const double _kPaddingValue = 0.0;

  // --- Texture State ---
  gpu.Texture? _texture;

  CheckerBoardUniforms({super.vertexShader, super.fragmentShader}) {
    // Establish initialization values inside the string data store
    this[_kPatternColor1Key] = _kDefaultPatternColor1;
    this[_kPatternColor2Key] = _kDefaultPatternColor2;
    this[_kUseTextureKey] = _kDefaultUseTexture;
    this[_kTextureMixKey] = _kDefaultTextureMix;
    this[_kPatternScaleKey] = _kDefaultPatternScale;
  }

  // --- Type-Safe Public Setters ---
  set patternColor1(Color val) => this[_kPatternColor1Key] = val;
  set patternColor2(Color val) => this[_kPatternColor2Key] = val;
  set useTexture(bool val) => this[_kUseTextureKey] = val;
  set textureMix(double val) => this[_kTextureMixKey] = val;
  set patternScale(double val) => this[_kPatternScaleKey] = val;
  set texture(gpu.Texture? val) => _texture = val;

  @override
  Float32List serializeFragmentData() {
    final Float32List fragmentData = Float32List(_kFragmentDataFloatCount);
    int offset = 0;

    // Pull from the map dynamically by constant name
    offset = packColor(fragmentData, offset, this[_kPatternColor1Key] as Color);
    offset = packColor(fragmentData, offset, this[_kPatternColor2Key] as Color);

    final bool useTex = this[_kUseTextureKey] as bool;
    fragmentData[_kUseTextureBufferIndex] = useTex ? _kBooleanTrueValue : _kBooleanFalseValue;
    fragmentData[_kTextureMixBufferIndex] = (this[_kTextureMixKey] as num).toDouble();
    fragmentData[_kPatternScaleBufferIndex] = (this[_kPatternScaleKey] as num).toDouble();
    fragmentData[_kPaddingBufferIndex] = _kPaddingValue; // Struct alignment padding

    return fragmentData;
  }

  /// Extends the base bind pass to handle the texture binding step.
  @override
  void bind(gpu.RenderPass renderPass) {
    // 1. Run the base routine to bind Vertex matrices and block configurations
    super.bind(renderPass);

    // 2. Safely look up and bind the texture sampling asset
    if (_texture != null && fragmentShader != null) {
      final gpu.UniformSlot textureSlot = fragmentShader!.getUniformSlot(_kSamplerUniformName);
      renderPass.bindTexture(textureSlot, _texture!);
    }
  }
}
