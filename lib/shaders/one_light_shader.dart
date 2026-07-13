import 'dart:ui';
import 'package:flutter_angle/shared/classes.dart';
import 'package:fsk/angle/gl_state_manager.dart';
import 'package:vector_math/vector_math_64.dart';
import '../angle/glsl_shader.dart';
import '../util.dart';

const String _vertexShader = """
#version 300 es
// Define precision for floating-point variables
precision mediump float;

// Input vertex attributes
layout (location = 0) in vec3 aVertexPosition;
layout (location = 1) in vec2 aTextureCoord;
layout (location = 2) in vec3 aVertexNormal; 
layout (location = 3) in vec4 aVertexColor; 

// Output to fragment shader
out vec2 vTextureCoord;   // Interpolated texture coordinate
out vec3 vLightIntensity; // Interpolated light intensity
out vec3 barycentricCoords;  // Barycentric coordinates for outline

// Uniform variables (set from the application)
uniform mat4 uMVMatrix;       // Model-view matrix
uniform mat4 uPMatrix;        // Projection matrix
uniform mat3 uNMatrix;        // Normal matrix (for transforming normals)
uniform vec3 uLightPos;       // Light position in eye space
uniform vec3 uAmbientLight;   // Ambient light color
uniform vec3 uDiffuseLight;   // Diffuse light color
uniform vec3 uSpecularLight;  // Specular light color
uniform vec3 uMaterialAmbient; // Material ambient color
uniform vec3 uMaterialDiffuse; // Material diffuse color
uniform vec3 uMaterialSpecular; // Material specular color
uniform float uMaterialShininess; // Material shininess       

void main(void) {
    // Transform vertex position to eye space
    vec4 eyeCoords = uMVMatrix * vec4(aVertexPosition, 1.0);

    // Calculate light direction in eye space
    vec3 lightDir = normalize(uLightPos - vec3(eyeCoords)); // Direction from vertex to light source

    // Transform normal to eye space
    vec3 transformedNormal = normalize(uNMatrix * aVertexNormal); // Remember to normalize normals after transformation

    // Calculate diffuse lighting (Lambertian reflectance)
    float diff = max(dot(transformedNormal, lightDir), 0.0);
    vec3 diffuse = uDiffuseLight * uMaterialDiffuse * diff;

    // Calculate ambient lighting
    vec3 ambient = uAmbientLight * uMaterialAmbient;

    // Calculate specular lighting (Phong model)
    vec3 viewDir = normalize(-eyeCoords.xyz); // Direction from vertex to camera/viewer
    vec3 reflectDir = reflect(-lightDir, transformedNormal); // Reflection vector

    float spec = pow(max(dot(viewDir, reflectDir), 0.0), uMaterialShininess);
    vec3 specular = uSpecularLight * uMaterialSpecular * spec;

    // Combine lighting components
    vLightIntensity = ambient + diffuse + specular;

    // Pass texture coordinates to fragment shader
    vTextureCoord = aTextureCoord;

    // Transform vertex position to clip space
    gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
    
    // For outlines
    int vertexInTriangle = gl_VertexID % 3;
     
    if (vertexInTriangle == 0) { 
      barycentricCoords = vec3(1.0, 0.0, 0.0);
    }
    else if (vertexInTriangle == 1) {
      barycentricCoords = vec3(0.0, 1.0, 0.0);
    }
    else barycentricCoords = vec3(0.0, 0.0, 1.0); 
}
""";

const String _fragmentShader = """
#version 300 es

// Define precision for floating-point variables
precision mediump float; // Fragment shaders often use mediump for performance

// Input from vertex shader (interpolated across the primitive)
in vec2 vTextureCoord;
in vec3 vLightIntensity;
in vec3 barycentricCoords;

uniform bool uOutlineEnabled;  // true if outline enabled    
uniform bool uDrawFill;        // true if fill enabled
uniform vec4 uOutlineColor;    // outline color
uniform float uOutlineWidth;    // outline width

// Output fragment color
out vec4 FragColor;

void main(void) {
    // Calculate the outline factor first, as it's common to both modes
    vec3 d = fwidth(barycentricCoords);
    vec3 a3 = smoothstep(vec3(0.0), d * uOutlineWidth, barycentricCoords);
    float outlineFactor = min(min(a3.x, a3.y), a3.z);

    vec4 finalColor;

    if (uDrawFill) {
        // If fill is enabled, start with the lit color (fill)
        finalColor = vec4(vLightIntensity, 1.0);
        if (uOutlineEnabled) {
            // Mix outline color with the fill color
            finalColor = mix(uOutlineColor, finalColor, outlineFactor);
        }
    } else {
        // If fill is disabled, start with fully transparent
        finalColor = vec4(0.0, 0.0, 0.0, 0.0);
        if (uOutlineEnabled) {
            // Mix outline color with the transparent color
            finalColor = mix(uOutlineColor, finalColor, outlineFactor);
        }
    }

    FragColor = finalColor;
}

""";

class OneLightShader extends GlslShader {
  static String uLightPos = "uLightPos"; // Light position in eye coordinates
  static String uNMatrix =
      "uNMatrix"; // Normal matrix (for transforming normals)
  static String uAmbientLight = "uAmbientLight"; // Ambient light color
  static String uDiffuseLight = "uDiffuseLight"; // Diffuse light color
  static String uSpecularLight = "uSpecularLight"; // Specular light color
  static String uMaterialAmbient = "uMaterialAmbient"; // Material ambient color
  static String uMaterialDiffuse = "uMaterialDiffuse"; // Material diffuse color
  static String uMaterialSpecular =
      "uMaterialSpecular"; // Material specular color
  static String uMaterialShininess = "uMaterialShininess"; // Material shininess

  static String uOutlineEnabled = "uOutlineEnabled";
  static String uOutlineColor = "uOutlineColor";
  static String uOutlineWidth = "uOutlineWidth";

  static String uDrawFill = "uDrawFill";

  late UniformLocation _lightPosLocation;
  late UniformLocation _nMatrixLocation;
  late UniformLocation _ambientLightLocation;
  late UniformLocation _diffuseLightLocation;
  late UniformLocation _specularLightLocation;
  late UniformLocation _materialAmbientLocation;
  late UniformLocation _materialDiffuseLocation;
  late UniformLocation _materialSpecularLocation;
  late UniformLocation _materialShininessLocation;
  late UniformLocation _outlineEnabledLocation;
  late UniformLocation _outlineColorLocation;
  late UniformLocation _outlineWidthLocation;
  late UniformLocation _drawFillLocation;

  OneLightShader(GlStateManager gls)
    : super(
        gls,
        _fragmentShader,
        _vertexShader,
        [GlslShader.v3Attrib, GlslShader.t2Attrib, GlslShader.n3Attrib],
        [
          uLightPos,
          uNMatrix,
          uAmbientLight,
          uDiffuseLight,
          uSpecularLight,
          uMaterialAmbient,
          uMaterialDiffuse,
          uMaterialSpecular,
          uMaterialShininess,
          uOutlineEnabled,
          uDrawFill,
          uOutlineColor,
          uOutlineWidth,
          GlslShader.uModelView,
          GlslShader.uProj,
        ],
      ) {
    _lightPosLocation = uniforms[uLightPos]!;
    _nMatrixLocation = uniforms[uNMatrix]!;
    _ambientLightLocation = uniforms[uAmbientLight]!;
    _diffuseLightLocation = uniforms[uDiffuseLight]!;
    _specularLightLocation = uniforms[uSpecularLight]!;
    _materialAmbientLocation = uniforms[uMaterialAmbient]!;
    _materialDiffuseLocation = uniforms[uMaterialDiffuse]!;
    _materialSpecularLocation = uniforms[uMaterialSpecular]!;
    _materialShininessLocation = uniforms[uMaterialShininess]!;
    _outlineEnabledLocation = uniforms[uOutlineEnabled]!;
    _outlineColorLocation = uniforms[uOutlineColor]!;
    _outlineWidthLocation = uniforms[uOutlineWidth]!;
    _drawFillLocation = uniforms[uDrawFill]!;
  }

  void setLightPos(Vector3 v) {
    gls.setUniform3fv(_lightPosLocation, [v.x, v.y, v.z]);
  }

  void setNMatrix(Matrix3 m) {
    gls.setUniformMatrix3fv(_nMatrixLocation, m);
  }

  void setAmbientLight(Color color) {
    gls.setUniform3fv(_ambientLightLocation, [color.r, color.g, color.b]);
  }

  void setDiffuseLight(Color color) {
    gls.setUniform3fv(_diffuseLightLocation, [color.r, color.g, color.b]);
  }

  void setSpecularLight(Color color) {
    gls.setUniform3fv(_specularLightLocation, [color.r, color.g, color.b]);
  }

  void setMaterialAmbient(Color color) {
    gls.setUniform3fv(_materialAmbientLocation, [color.r, color.g, color.b]);
  }

  void setMaterialDiffuse(Color color) {
    gls.setUniform3fv(_materialDiffuseLocation, [color.r, color.g, color.b]);
  }

  void setMaterialSpecular(Color color) {
    gls.setUniform3fv(_materialSpecularLocation, [
      color.r,
      color.g,
      color.b,
    ]);
  }

  void setShininess(num shininess) {
    gls.setUniform1f(_materialShininessLocation, shininess.toDouble());
  }

  void setOutlineEnabled(bool enabled) {
    gls.setUniform1i(_outlineEnabledLocation, enabled ? 1 : 0);
  }

  void setDrawFill(bool enabled) {
    gls.setUniform1i(_drawFillLocation, enabled ? 1 : 0);
  }

  void setOutlineColor(Color color) {
    gls.setUniform4fv(_outlineColorLocation, [
      color.r,
      color.g,
      color.b,
      color.a,
    ]);
  }

  void setOutlineWidth(num width) {
    gls.setUniform1f(_outlineWidthLocation, width.toDouble());
  }

  @override
  void setUniformValue(String name, String value) {
    if (name == uLightPos) {
      setLightPos(parseVector3(value));
    } else if (name == uAmbientLight) {
      setAmbientLight(parseHexColor(value));
    } else if (name == uDiffuseLight) {
      setDiffuseLight(parseHexColor(value));
    } else if (name == uSpecularLight) {
      setSpecularLight(parseHexColor(value));
    } else if (name == uMaterialAmbient) {
      setMaterialAmbient(parseHexColor(value));
    } else if (name == uMaterialDiffuse) {
      setMaterialDiffuse(parseHexColor(value));
    } else if (name == uMaterialSpecular) {
      setMaterialSpecular(parseHexColor(value));
    } else if (name == uMaterialShininess) {
      final val = double.tryParse(value);
      if (val != null) setShininess(val);
    } else if (name == uOutlineEnabled) {
      setOutlineEnabled(value.toLowerCase() == 'true' || value == '1');
    } else if (name == uOutlineColor) {
      setOutlineColor(parseHexColor(value));
    } else if (name == uOutlineWidth) {
      final val = double.tryParse(value);
      if (val != null) setOutlineWidth(val);
    } else if (name == uDrawFill) {
      setDrawFill(value.toLowerCase() == 'true' || value == '1');
    } else {
      super.setUniformValue(name, value);
    }
  }
}
