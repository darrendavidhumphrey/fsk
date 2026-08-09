import 'package:vector_math/vector_math.dart';
import 'base_uniforms.dart';
import 'materials.dart';
import 'dart:ui';

class LightingUniforms extends BaseUniforms {
  static const String _kKdKey = 'Kd';
  static const String _kLdKey = 'Ld';
  static const String _kLightPosKey = 'lightPos';
  static const String _kWorldLightPosKey = 'worldLightPos';

  @override
  String get vertexBlockName => 'LightingVertexUniforms';
  @override
  String get fragmentBlockName => 'LightingFragmentUniforms';

  LightingUniforms({super.vertexShader, super.fragmentShader}) {
    this[_kKdKey] = const Color(0xFFFFFFFF);
    this[_kLdKey] = Vector3(1.0, 1.0, 1.0);
    this[_kLightPosKey] = Vector3.zero();
    this[_kWorldLightPosKey] = Vector3(200.0, 200.0, 200.0);
  }

  @override
  bool get hasSampler => true;
  @override
  String get samplerUniformName => 'uSampler';

  set kd(Vector3 val) => this[_kKdKey] = val;
  set ld(Vector3 val) => this[_kLdKey] = val;
  set lightPos(Vector3 val) => this[_kWorldLightPosKey] = val;

  @override
  void onUpdate(Size viewportSize) {
    final Vector3 worldPos = (this[_kWorldLightPosKey] as Vector3?) ?? Vector3(200, 200, 200);
    final Vector4 viewPos = mvMatrixLocal.transform(Vector4(worldPos.x, worldPos.y, worldPos.z, 1.0));
    this[_kLightPosKey] = Vector3(viewPos.x, viewPos.y, viewPos.z);
  }

  @override
  void applyMaterial(GlMaterial material) {
    this[_kKdKey] = material.diffuse;
  }

  @override
  void serializeFragmentData() {
    fragmentData.clear();
    fragmentData.packVector3(valuesMap[_kKdKey]);
    fragmentData.packVector3(valuesMap[_kLdKey]);
    fragmentData.packVector3(valuesMap[_kLightPosKey]);
  }
}
