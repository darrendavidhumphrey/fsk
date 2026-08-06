import 'package:flutter/material.dart' hide Matrix4;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

// Loads a simple OBJ model and puts it in an orbit view
class ObjModelScene extends FskFrameScene {
  ObjModelScene({super.navigationDelegate});

  @override
  Future<void> onInit() async {
    await super.onInit();
    useBoxFitLayout = false;
    clearColor = Colors.blueGrey;

    // Load the teapot model, and have the model loader load the texture
    // Defaults to using the built-in LightingShader if no shader material is provided
    final teapotModel = await WavefrontObjModel.loadFromAssets(
      assetFile: 'assets/3D/Teapot/teapot_textures_normals.obj',
      parentScene: this,
      sceneId: 'teapot',
      loadTexture: () => FSK().textureManager.createTextureFromAsset(
            'Bricks',
            '3D/Teapot/Bricks051_1K-JPG_Color.jpg',
          ),
      onModelLoaded: (model) {
        model.transformable.scale = Vector3.all(5.0);
        final uniforms = model.mesh.uniforms as LightingUniforms;
        uniforms.lightPos = Vector3(500, 500, 500);
      },
    );

    addNode(teapotModel);
  }
}
