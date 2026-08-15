import 'dart:ui';
import 'base_uniforms.dart';
import 'materials.dart';
import 'package:vector_math/vector_math.dart' as vm;

class WireFrameUniforms extends BaseUniforms {
  static const String _kIsHeadlampKey = 'isHeadlamp';
  static const String _kWorldLightPosKey = 'worldLightPos';

  @override
  String get vertexBlockName => 'WireFrameVertexUniforms';
  @override
  String get fragmentBlockName => 'WireFrameFragmentUniforms';

  WireFrameUniforms({super.vertexShader, super.fragmentShader}) {
    // Fragment Defaults
    this['lightPos'] = vm.Vector3.zero();
    this[_kWorldLightPosKey] = vm.Vector3(200.0, 200.0, 200.0);
    this[_kIsHeadlampKey] = true; // Default to headlamp

    this['ambientLight'] = const Color(0xFF404040);
    this['diffuseLight'] = const Color(0xFFCCCCCC); // Softer diffuse
    this['specularLight'] = const Color(0xFF404040); // Soft specular
    this['materialAmbient'] = const Color(0xFFFFFFFF);
    this['materialDiffuse'] = const Color(0xFFFFFFFF);
    this['materialSpecular'] = const Color(0xFFFFFFFF);
    this['outlineColor'] = const Color(0xFF000000);
    
    // uConfig: x=shininess, y=outlineEnabled, z=drawFill, w=lineWidth
    this['shininess'] = 16.0; // Lower shininess for softer look
    this['outlineEnabled'] = 1.0;
    this['drawFill'] = 1.0;
    this['lineWidth'] = 1.5;
  }

  @override
  void onUpdate(Size viewportSize) {
    if (this[_kIsHeadlampKey] as bool) {
      // Light is at the camera in View Space
      this['lightPos'] = vm.Vector3.zero();
      return;
    }

    final dynamic worldPosVal = valuesMap[_kWorldLightPosKey];
    final vm.Vector3 worldPos = (worldPosVal is vm.Vector3) ? worldPosVal : vm.Vector3(200, 200, 200);
    final vm.Vector4 viewPos = mvMatrixLocal.transform(vm.Vector4(worldPos.x, worldPos.y, worldPos.z, 1.0));
    this['lightPos'] = vm.Vector3(viewPos.x, viewPos.y, viewPos.z);
  }

  @override
  void applyMaterial(GlMaterial material) {
    this['materialDiffuse'] = material.diffuse;
    this['materialAmbient'] = material.diffuse;
  }

  @override
  void serializeFragmentData() {
    fragmentData.clear();
    fragmentData.packVector3(valuesMap['lightPos']);
    fragmentData.packColor(valuesMap['ambientLight']);
    fragmentData.packColor(valuesMap['diffuseLight']);
    fragmentData.packColor(valuesMap['specularLight']);
    fragmentData.packColor(valuesMap['materialAmbient']);
    fragmentData.packColor(valuesMap['materialDiffuse']);
    fragmentData.packColor(valuesMap['materialSpecular']);
    fragmentData.packColor(valuesMap['outlineColor']);
    
    // uConfig (vec4)
    fragmentData.packDouble(valuesMap['shininess']);
    fragmentData.packDouble(valuesMap['outlineEnabled']);
    fragmentData.packDouble(valuesMap['drawFill']);
    fragmentData.packDouble(valuesMap['lineWidth']);
  }
}
