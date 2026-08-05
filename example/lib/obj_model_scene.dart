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

  void init() async {
    try {
      useBoxFitLayout = false;
      clearColor = Colors.blueGrey;

      // Load the teapot model using the new load method
      FskTextureInfo? teapotTexture = await loadTexture();
      FskGroup teapotModel = await WavefrontObjModel.load(
        'assets/3D/Teapot/teapot_textures_normals.obj',
        this,
        'teapot',
      );

      if (teapotTexture != null) {
        // Caller's frame of reference is now 0, no manual rotation needed!
        teapotModel.transformable.scale = Vector3.all(5.0);

        // Find the mesh by its hierarchical path
        final mesh = teapotModel.findNode<FskIndexedMesh>('teapot_correction.teapot');
        if (mesh != null) {
          final LightingUniforms uniforms = LightingUniforms();
          mesh.renderer.uniforms = uniforms;

          uniforms.lightPos = Vector3(500, 500, 500);

          // Bind the texture to the shader
          uniforms.texture = teapotTexture.texture;
          uniforms.samplerOptions = teapotTexture.samplerOptions;
        }

        // Add the teapot root to the scene graph
        addNode(teapotModel);
      }
      isReady = true;
    } catch (e, s) {
      logError("Error in ObjModelScene.init: $e\n$s");
      // Mark ready anyway so the test doesn't hang forever
      isReady = true;
    }
  }
}
