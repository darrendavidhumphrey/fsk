import 'dart:typed_data';
import 'dart:ui';
import 'materials.dart';

import 'base_uniforms.dart';

class SimpleTextureUniforms extends BaseUniforms {
  static const String _kModulateColorKey = 'uModulateColor';

  @override
  String get vertexBlockName => 'SimpleTextureVertexUniforms';
  @override
  String get fragmentBlockName => 'SimpleTextureFragmentUniforms';

  SimpleTextureUniforms({super.vertexShader, super.fragmentShader}) {
    this[_kModulateColorKey] = const Color(0xFFFFFFFF);
  }

  void setModulateColor(Color color) {
    this[_kModulateColorKey] = color;
  }

  @override
  void applyMaterial(GlMaterial material) {
    this[_kModulateColorKey] = material.diffuse;
  }

  @override
  void serializeFragmentData() {
    fragmentData.clear();
    fragmentData.packColor(valuesMap[_kModulateColorKey]);
  }
}
