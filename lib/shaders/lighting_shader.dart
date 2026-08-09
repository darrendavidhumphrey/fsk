import 'dart:typed_data';
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
    this[_kKdKey] = Vector3(1.0, 1.0, 1.0);
    this[_kLdKey] = Vector3(1.0, 1.0, 1.0);
    this[_kLightPosKey] = Vector3(0.0, 0.0, 0.0);
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
  Float32List serializeFragmentData() {
    final Float32List fragmentData = Float32List(20);

    final dynamic kdVal = this[_kKdKey];
    if (kdVal is Color) {
      fragmentData[0] = kdVal.r;
      fragmentData[1] = kdVal.g;
      fragmentData[2] = kdVal.b;
    } else if (kdVal is Vector3) {
      fragmentData[0] = kdVal.x;
      fragmentData[1] = kdVal.y;
      fragmentData[2] = kdVal.z;
    }
    fragmentData[3] = 1.0; 

    final dynamic ldVal = this[_kLdKey];
    if (ldVal is Vector3) {
      fragmentData[4] = ldVal.x;
      fragmentData[5] = ldVal.y;
      fragmentData[6] = ldVal.z;
    }
    fragmentData[7] = 1.0;

    final dynamic lpVal = this[_kLightPosKey];
    if (lpVal is Vector3) {
      fragmentData[8] = lpVal.x;
      fragmentData[9] = lpVal.y;
      fragmentData[10] = lpVal.z;
    }
    fragmentData[11] = 1.0;

    return fragmentData;
  }
}
