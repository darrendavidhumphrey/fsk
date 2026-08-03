import 'package:flutter/material.dart' hide Matrix4;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

// Loads a simple OBJ model and puts it in an orbit view
class ObjModelScene extends FskFrameScene {
  ObjModelScene({super.navigationDelegate}) {
    init();
  }

  Future<FskTextureInfo?> loadTexture() async {
    try {
      // 1. Pre-load the texture
      return await FSK().textureManager.createTextureFromAsset(
        'Bricks',
        '3D/Teapot/Bricks051_1K-JPG_Color.jpg',
      );
    } catch (e) {
      logError("Error loading texture: $e");
      return null;
    }
  }

  Future<FskIndexedMesh?> loadTeapot() async {
    try {
      return await WavefrontObjModel.indexedMeshFromAsset(
        'assets/3D/Teapot/teapot_textures_normals.obj',
        this,
        'teapot',
      );
    } catch (e) {
      logError("Error loading teapot: $e");
      return null;
    }
  }

  void init() async {
    useBoxFitLayout = false;
    clearColor = Colors.blueGrey;

    // Load the teapot model
    FskTextureInfo? teapotTexture = await loadTexture();
    FskIndexedMesh? teapotMesh = await loadTeapot();

    if ((teapotMesh != null) && (teapotTexture != null)) {
      teapotMesh.transformable.scale = Vector3.all(5.0);

      // Flip over the teapot
      teapotMesh.transformable.rotation = Vector3(0, 0, radians(180));

      final LightingUniforms uniforms = LightingUniforms();

      teapotMesh.renderer.uniforms = uniforms;

      uniforms.lightPos = Vector3(500, 500, 500);

      // Bind the texture to the shader
      uniforms.texture = teapotTexture.texture;
      uniforms.samplerOptions = teapotTexture.samplerOptions;

      // Add the teapot to the scene graph
      addNode(teapotMesh);
    }
    isReady = true;
  }
}
