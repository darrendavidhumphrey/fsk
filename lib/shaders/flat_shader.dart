import 'dart:typed_data';
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
  Float32List serializeFragmentData() {
    final Float32List fragmentData = Float32List(BaseUniforms.kFragmentDataFloatCount);
    packColor(fragmentData, 0, valuesMap[_kModulateColor]);
    return fragmentData;
  }
}
