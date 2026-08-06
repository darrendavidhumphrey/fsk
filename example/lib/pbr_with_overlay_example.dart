import 'package:flutter/material.dart' hide Matrix4;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' hide Colors;
import 'pbr_model_scene.dart';

/// A concrete implementation of a screen-space overlay that displays a teapot.
class TeapotOverlay extends ScreenSpaceOverlay {
  TeapotOverlay({
    required super.id,
    super.top,
    super.right,
    super.left,
    super.bottom,
    required super.screenSpaceSize,
    super.interceptInput,
    super.navigationDelegate,
  });

  @override
  Future<void> onInit() async {
    await super.onInit();
    // Overlays typically don't use box-fit layout as they are explicitly sized
    useBoxFitLayout = false;

    // Load the teapot model into this overlay's scene graph
    final teapotModel = await WavefrontObjModel.loadFromAssets(
      assetFile: 'assets/3D/Teapot/teapot_textures_normals.obj',
      parentScene: this,
      sceneId: 'teapot_overlay_$id',
      loadTexture: () => FSK().textureManager.createTextureFromAsset(
            'Bricks_Overlay',
            '3D/Teapot/Bricks051_1K-JPG_Color.jpg',
          ),
      onModelLoaded: (model) {
        // Center and scale the teapot for the overlay viewport
        model.transformable.scale = Vector3.all(5.0);
        
        // Use the standard lighting uniforms since ObjModel defaults to LightingShader
        final uniforms = model.mesh.uniforms as LightingUniforms;
        uniforms.lightPos = Vector3(500, 500, 500);
      },
    );

    addNode(teapotModel);
  }
}

/// A scene that extends the PBR model scene and adds a teapot overlay in the corner.
class PbrWithOverlayScene extends PbrModelScene {
  PbrWithOverlayScene({super.navigationDelegate, super.clearColor});

  @override
  Future<void> onInit() async {
    // Initialize the base PBR model scene first
    await super.onInit();

    // Create the overlay in the upper right corner - Opts in to input
    final teapotOverlayRight = TeapotOverlay(
      id: 'teapot_pip_right',
      right: 20,
      top: 20,
      screenSpaceSize: const Size(400, 400),
      interceptInput: true,
      // Use an orbit delegate so we can see the teapot from different angles
      navigationDelegate: OrbitViewDelegate(boxFit: FskBoxFit.bestFit),
    );

    // Create the overlay in the upper left corner - Does NOT opt in
    final teapotOverlayLeft = TeapotOverlay(
      id: 'teapot_pip_left',
      left: 20,
      top: 20,
      screenSpaceSize: const Size(200, 200),
      interceptInput: false,
      navigationDelegate: OrbitViewDelegate(boxFit: FskBoxFit.bestFit),
    );

    // Add the overlays as layers to this scene
    addLayer(teapotOverlayRight);
    addLayer(teapotOverlayLeft);
  }
}
