import 'dart:typed_data';
import 'dart:ui';
import 'base_uniforms.dart';
import 'materials.dart';

class FlatUniforms extends BaseUniforms {
  // Uniform name constant
  static const String _kModulateColor = 'modulateColor';

  FlatUniforms({super.vertexShader, super.fragmentShader}) {
    // Establish initialization values inside the string data store
    this[_kModulateColor] = const Color(0xFFFFFFFF);
  }

  // Type-safe wrapper pointing directly to the constant key
  set modulateColor(Color val) => this[_kModulateColor] = val;

  @override
  void applyMaterial(GlMaterial material) {
    setValueSilent(_kModulateColor, material.diffuse);
  }

  @override
  Float32List serializeFragmentData() {
    final Float32List fragmentData = Float32List(4);

    // Pack modulateColor into the first 4 floats (16 bytes)
    packColor(fragmentData, 0, this[_kModulateColor] as Color);

    return fragmentData;
  }
}
