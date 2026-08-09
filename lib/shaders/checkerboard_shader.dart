import 'dart:typed_data';
import 'dart:ui';
import 'base_uniforms.dart';

class CheckerBoardUniforms extends BaseUniforms {
  static const String _kPatternColor1Key = 'patternColor1';
  static const String _kPatternColor2Key = 'patternColor2';
  static const String _kUseTextureKey = 'useTexture';
  static const String _kTextureMixKey = 'textureMix';
  static const String _kPatternScaleKey = 'patternScale';

  @override
  String get vertexBlockName => 'CheckerBoardVertexUniforms';
  @override
  String get fragmentBlockName => 'CheckerBoardFragmentUniforms';

  @override
  bool get hasSampler => true;

  CheckerBoardUniforms({super.vertexShader, super.fragmentShader}) {
    this[_kPatternColor1Key] = const Color(0xFFFFFFFF);
    this[_kPatternColor2Key] = const Color(0xFF000000);
    this[_kUseTextureKey] = false;
    this[_kTextureMixKey] = 0.0;
    this[_kPatternScaleKey] = 1.0;
  }

  set patternColor1(Color val) => this[_kPatternColor1Key] = val;
  set patternColor2(Color val) => this[_kPatternColor2Key] = val;
  set useTexture(bool val) => this[_kUseTextureKey] = val;
  set textureMix(double val) => this[_kTextureMixKey] = val;
  set patternScale(double val) => this[_kPatternScaleKey] = val;

  @override
  Float32List serializeFragmentData() {
    final Float32List fragmentData = Float32List(BaseUniforms.kFragmentDataFloatCount);
    int offset = 0;
    offset = packColor(fragmentData, offset, valuesMap[_kPatternColor1Key]);
    offset = packColor(fragmentData, offset, valuesMap[_kPatternColor2Key]);
    offset = packBool(fragmentData, offset, valuesMap[_kUseTextureKey]);
    offset = packDouble(fragmentData, offset, valuesMap[_kTextureMixKey]);
    offset = packDouble(fragmentData, offset, valuesMap[_kPatternScaleKey]);
    return fragmentData;
  }
}
