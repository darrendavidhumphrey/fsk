import 'dart:typed_data';
import 'dart:ui';
import 'package:vector_math/vector_math.dart' as vm;
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

  @override
  bool get hasSampler => true;
  @override
  String get samplerUniformName => 'uSampler';

  void setModulateColor(Color color) {
    this[_kModulateColorKey] = color;
  }

  @override
  void applyMaterial(GlMaterial material) {
    this[_kModulateColorKey] = material.diffuse;
  }

  @override
  Float32List serializeFragmentData() {
    final Float32List fragmentData = Float32List(20);

    final dynamic colorVal = valuesMap[_kModulateColorKey];
    
    if (colorVal is Color) {
      fragmentData[0] = colorVal.r;
      fragmentData[1] = colorVal.g;
      fragmentData[2] = colorVal.b;
      fragmentData[3] = colorVal.a;
    } else if (colorVal is vm.Vector4) {
      fragmentData[0] = colorVal.x;
      fragmentData[1] = colorVal.y;
      fragmentData[2] = colorVal.z;
      fragmentData[3] = colorVal.w;
    } else {
      fragmentData[0] = 1.0;
      fragmentData[1] = 1.0;
      fragmentData[2] = 1.0;
      fragmentData[3] = 1.0;
    }

    return fragmentData;
  }
}
