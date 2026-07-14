import 'package:vector_math/vector_math_64.dart';
import '../angle/gl_state_manager.dart';
import '../angle/glsl_shader.dart';

abstract class FskSceneObject {

  // API for dynamically controlling uniforms
  List<UniformValue> uniformValues = [];
  void initShaderParams(Map<String, String> params);
  void applyShaderParams();


  void drawSetup(GlStateManager gls, Matrix4 pMatrix, Matrix4 mvMatrix);
  void draw(GlStateManager gls);
  void init(GlStateManager gls);
  void rebuild(GlStateManager gls);
  void dispose();
}

class FskRenderableObject extends FskSceneObject {

  GlslShader? _shader;

  GlslShader? get shader => _shader;

  void setShader(GlslShader? s) {
    _shader = s;
  }

  // Get a pointer to the UniformValue for a given UniformDefinition,
  // Create one if it doesn't exist
  UniformValue ? getUniformValue(UniformDefinition uniform) {
    for (var uniform in uniformValues) {
      if (uniform.definition == uniform.definition) {
        return uniform;
      }
    }

    // Create an empty value
    UniformValue newUniform = UniformValue(uniform, null);
    uniformValues.add(newUniform);
    return newUniform;
  }

  @override
  void initShaderParams(Map<String, String> params) {
    if (_shader == null) return;
    uniformValues.clear();
    params.forEach((name, value) {
      var location = _shader!.uniforms[name];
      if (location != null) {
        var typedValue = _shader!.uniformValueFromString(name, value);
        uniformValues.add(UniformValue(location, typedValue));
      }
    });
  }

  @override
  void applyShaderParams() {
    for (var uniform in uniformValues) {
      _shader!.setUniform(uniform.definition, uniform.value);
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
  }

  @override
  void draw(GlStateManager gls) {
    // TODO: implement draw
  }

  @override
  void drawSetup(GlStateManager gls, Matrix4 pMatrix, Matrix4 mvMatrix) {
    // TODO: implement drawSetup
  }

  @override
  void init(GlStateManager gls) {
    // TODO: implement init
  }

  @override
  void rebuild(GlStateManager gls) {
    // TODO: implement rebuild
  }

}
