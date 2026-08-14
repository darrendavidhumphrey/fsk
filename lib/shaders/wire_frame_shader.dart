import 'dart:ui';
import 'base_uniforms.dart';
import 'package:vector_math/vector_math.dart' as vm;

class WireFrameUniforms extends BaseUniforms {
  @override
  String get vertexBlockName => 'WireFrameVertexUniforms';
  @override
  String get fragmentBlockName => 'WireFrameFragmentUniforms';

  WireFrameUniforms({super.vertexShader, super.fragmentShader}) {
    // Fragment Defaults
    this['lightPos'] = vm.Vector3(100.0, 100.0, 100.0);
    this['ambientLight'] = const Color(0xFF404040);
    this['diffuseLight'] = const Color(0xFFFFFFFF);
    this['specularLight'] = const Color(0xFFFFFFFF);
    this['materialAmbient'] = const Color(0xFFFFFFFF);
    this['materialDiffuse'] = const Color(0xFFFFFFFF);
    this['materialSpecular'] = const Color(0xFFFFFFFF);
    this['outlineColor'] = const Color(0xFF000000);
    
    // uConfig: x=shininess, y=outlineEnabled, z=drawFill, w=lineWidth
    this['shininess'] = 32.0;
    this['outlineEnabled'] = 1.0;
    this['drawFill'] = 1.0;
    this['lineWidth'] = 1.5;
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
