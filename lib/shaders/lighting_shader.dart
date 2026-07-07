import 'package:flutter_angle/shared/classes.dart';
import 'package:vector_math/vector_math_64.dart';

import '../gl_state_manager.dart';
import '../glsl_shader.dart';

const String _lightingVertexShader = """
#version 300 es
precision mediump float; // You can adjust this based on your needs

layout (location = 0) in vec3 aVertexPosition;
layout (location = 1) in vec2 aTextureCoord;
layout (location = 2) in vec3 aNormal; 
layout (location = 3) in vec4 aVertexColor; 

out vec2 vTextureCoord;
out vec3 LightIntensity;
 
uniform vec3 Kd;  
uniform vec3 Ld;  
uniform vec4 lightPos; 
uniform mat4 uMVMatrix;
uniform mat4 uPMatrix;


void main() { 
   vec3 tnorm = aNormal; 
	 vec4 eyeCoords = uMVMatrix * vec4(aVertexPosition,1.0); 
	 vec3 s = normalize(vec3(lightPos - eyeCoords)); 
   vec3 ambient = vec3(0,0.0,0);
	 LightIntensity = Ld * Kd * max( dot( s, tnorm ), 0.0 ) + ambient; 
	 gl_Position =  uPMatrix * uMVMatrix * vec4(aVertexPosition,1.0); 
}
""";

const String _lightingFragmentShader = """
#version 300 es
precision highp float;
in vec2 vTextureCoord;
in vec3 LightIntensity; 
out vec4 FragColor;

uniform sampler2D uSampler;
 
void main() {
	FragColor = vec4(LightIntensity, 1.0); 
}
""";

class BasicLightingShader extends GlslShader {
  static String uLightPos = "lightPos";
  static String uKd = "Kd";
  static String uLd = "Ld";

  late UniformLocation _lightPosLocation;
  late UniformLocation _kdLocation;
  late UniformLocation _ldLocation;


  BasicLightingShader(GlStateManager gls)
    : super(
    gls,
        _lightingFragmentShader,
        _lightingVertexShader,
        [
          GlslShader.v3Attrib,
          GlslShader.t2Attrib,
          GlslShader.n3Attrib,
        ],
        [uKd, uLd, uLightPos, GlslShader.uModelView, GlslShader.uProj],
      ) {
    _lightPosLocation = uniforms[uLightPos]!;
    _kdLocation = uniforms[uKd]!;
    _ldLocation = uniforms[uLd]!;
  }

  void setLightPos(Vector3 v) {
    gls.setUniform4fv(_lightPosLocation, [v.x, v.y, v.z, 1.0]);
  }

  void setKd(Vector3 v) {
    gls.setUniform3fv(_kdLocation, [v.x, v.y, v.z]);
  }

  void setLd(Vector3 v) {
    gls.setUniform3fv(_ldLocation, [v.x, v.y, v.z]);
  }
}
