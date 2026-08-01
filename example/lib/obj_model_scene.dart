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
    
    // Load the teapot model
    // Note: The teapot.obj in this project is small, we'll need to scale it up
    try {
      teapotMesh = await WavefrontObjModel.indexedMeshFromAsset(
        'assets/teapot.obj', 
        this, 
        'teapot'
      );
      
      // The teapot is often defined in small units, scale it to be visible
      // in a world where "1 unit" is roughly 1 pixel in ortho, 
      // but in OrbitView we usually work in larger units.
      teapotMesh?.transformable.scale = Vector3.all(50.0);
      
      // Move it to center
      teapotMesh?.transformable.position = Vector3(0, 0, 0);

      navigationDelegate?.updateSceneMatrices(force: true);
    } catch (e) {
      print("Error loading teapot: $e");
    }
  }

  @override
  void drawScene(gpu.RenderPass renderPass, gpu.HostBuffer transients) {
    setupScissor(renderPass);
    
    if (teapotMesh != null) {
      // Set light position relative to the camera or world
      final renderer = teapotMesh!.renderer;

        if (renderer.uniforms is OneLightUniforms) {
          (renderer.uniforms as OneLightUniforms).lightPos = Vector3(200, 200, 200);
        }

      teapotMesh!.draw(renderPass, transients, pMatrix, mvMatrix);
    }
  }
}
