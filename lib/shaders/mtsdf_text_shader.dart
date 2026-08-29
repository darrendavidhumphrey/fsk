import 'dart:ui';
import 'base_uniforms.dart';

class MtsdfTextUniforms extends BaseUniforms {
  static const String _kTextColorKey = 'uTextColor';
  static const String _kGlowColorKey = 'uGlowColor';
  static const String _kGlowSizeKey = 'uGlowSize';

  @override
  String get vertexBlockName => 'MtsdfTextVertexUniforms';
  @override
  String get fragmentBlockName => 'MtsdfTextFragmentUniforms';

  MtsdfTextUniforms({super.vertexShader, super.fragmentShader}) {
    this[_kTextColorKey] = const Color(0xFFFFFFFF);
    this[_kGlowColorKey] = const Color(0x00000000);
    this[_kGlowSizeKey] = 0.0;
  }

  void setTextColor(Color color) {
    this[_kTextColorKey] = color;
  }

  void setGlowColor(Color color) {
    this[_kGlowColorKey] = color;
  }

  void setGlowSize(double size) {
    this[_kGlowSizeKey] = size;
  }

  @override
  void serializeFragmentData() {
    fragmentData.clear();
    fragmentData.packColor(valuesMap[_kTextColorKey]!);
    fragmentData.packColor(valuesMap[_kGlowColorKey]!);
    fragmentData.packDouble(valuesMap[_kGlowSizeKey] ?? 0.0);
  }
}
