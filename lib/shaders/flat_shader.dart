import 'dart:ui';
import 'base_uniforms.dart';
import 'materials.dart';

class FlatUniforms extends BaseUniforms {
  static const String _kModulateColor = 'modulateColor';

  @override
  String get vertexBlockName => 'FlatVertexUniforms';
  @override
  String get fragmentBlockName => 'FlatFragmentUniforms';

  FlatUniforms({super.vertexShader, super.fragmentShader}) {
    this[_kModulateColor] = const Color(0xFFFFFFFF);
  }

  set modulateColor(Color val) => this[_kModulateColor] = val;

  @override
  void applyMaterial(GlMaterial material) {
    this[_kModulateColor] = material.diffuse;
  }

  @override
  void serializeFragmentData() {
    fragmentData.clear();
    fragmentData.packColor(valuesMap[_kModulateColor]);
  }
}
