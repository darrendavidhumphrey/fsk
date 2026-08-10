import 'package:vector_math/vector_math.dart' as vm;
import 'base_uniforms.dart';
import 'materials.dart';
import 'dart:ui';

class LightingUniforms extends BaseUniforms {
  static const String _kKdKey = 'Kd';
  static const String _kLdKey = 'Ld';
  static const String _kLightPosKey = 'lightPos';
  static const String _kWorldLightPosKey = 'worldLightPos';
  static const String _kIsHeadlampKey = 'isHeadlamp';

  @override
  String get vertexBlockName => 'LightingVertexUniforms';
  @override
  String get fragmentBlockName => 'LightingFragmentUniforms';

  LightingUniforms({super.vertexShader, super.fragmentShader}) {
    this[_kKdKey] = const Color(0xFFFFFFFF);
    this[_kLdKey] = vm.Vector3(1.0, 1.0, 1.0);
    this[_kLightPosKey] = vm.Vector3.zero();
    this[_kWorldLightPosKey] = vm.Vector3(200.0, 200.0, 200.0);
    this[_kIsHeadlampKey] = false;
  }

  set kd(vm.Vector3 val) => this[_kKdKey] = val;
  set ld(vm.Vector3 val) => this[_kLdKey] = val;
  set lightPos(vm.Vector3 val) => this[_kWorldLightPosKey] = val;
  set isHeadlamp(bool val) => this[_kIsHeadlampKey] = val;

  @override
  void onUpdate(Size viewportSize) {
    if (this[_kIsHeadlampKey] as bool) {
      // Light is at the camera in View Space
      this[_kLightPosKey] = vm.Vector3.zero();
      return;
    }

    final dynamic worldPosVal = valuesMap[_kWorldLightPosKey];
    final vm.Vector3 worldPos = (worldPosVal is vm.Vector3) ? worldPosVal : vm.Vector3(200, 200, 200);
    final vm.Vector4 viewPos = mvMatrixLocal.transform(vm.Vector4(worldPos.x, worldPos.y, worldPos.z, 1.0));
    this[_kLightPosKey] = vm.Vector3(viewPos.x, viewPos.y, viewPos.z);
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
