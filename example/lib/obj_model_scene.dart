import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

class ObjModelScene extends FskScene {
  FskIndexedMesh? teapotMesh;

  ObjModelScene({super.navigationDelegate}) {
    init();
  }

  void init() async {
    clearColor = Colors.blueGrey;

    // Load the teapot model with textures and normals
    try {
      // 1. Pre-load the texture
      await FSK().textureManager.createTextureFromAsset(
        'Bricks',
        'Bricks051_1K-JPG_Color.jpg',
      );

      // 2. Load the mesh
      teapotMesh = await WavefrontObjModel.indexedMeshFromAsset(
        'assets/teapot_textures_normals.obj',
        this,
        'teapot',
      );

      if (teapotMesh != null) {
        teapotMesh!.transformable.scale = Vector3.all(5.0);
        teapotMesh!.transformable.position = Vector3(0, 0, 0);
        teapotMesh!.transformable.rotation = Vector3(0, 0, radians(180));
      }

      navigationDelegate?.updateSceneMatrices(force: true);
    } catch (e) {
      print("Error loading teapot: $e");
    }
  }

  @override
  void drawScene(gpu.RenderPass renderPass, gpu.HostBuffer transients) {
    setupScissor(renderPass);

    if (teapotMesh != null) {
      final renderer = teapotMesh!.renderer;

      if (renderer.uniforms is LightingUniforms) {
        final lu = renderer.uniforms as LightingUniforms;
        lu.lightPos = Vector3(500, 500, 500);

        // Ensure the texture is bound to the shader
        final texInfo = FSK().textureManager.getTextureInfo('Bricks');
        if (texInfo != null && texInfo.isLoaded) {
          renderer.uniforms!.texture = texInfo.texture;
          renderer.uniforms!.samplerOptions = texInfo.samplerOptions;
        }
      }

      teapotMesh!.draw(renderPass, transients, pMatrix, mvMatrix);
    }
  }
}
