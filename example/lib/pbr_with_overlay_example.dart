import 'package:flutter/material.dart' hide Matrix4;
import 'package:fsk/fsk.dart';
import 'package:fsk_examples/view_cube_overlay.dart';
import 'package:vector_math/vector_math.dart' hide Colors;
import 'pbr_model_scene.dart';

/// A concrete implementation of a screen-space overlay that displays a STL file.
class StlOverlay extends ScreenSpaceOverlay {
  StlOverlay({
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
    final stlModel = await StlLoader.loadFromAssets(
      assetFile: 'assets/3D/STL/honeycomb-wall.stl',
      parentScene: this,
      sceneId: 'honeycomb_wall_$id',
      onModelLoaded: (model) {
        // Center and scale the teapot for the overlay viewport
        model.transformable.scale = Vector3.all(1);
        model.centerModel();
        
        // Use the standard lighting uniforms since ObjModel defaults to LightingShader
        final uniforms = model.mesh.uniforms as LightingUniforms;
        uniforms.lightPos = Vector3(500, 500, 500);
      },
    );

    addNode(stlModel);
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
    final overlayRight = ViewCubeOverlay(
      id: 'pip_right',
      cubeSize: 50.0,
      right: 20,
      top: 20,
      screenSpaceSize: const Size(300, 300),
      interceptInput: true,
      // Use an orbit delegate so we can see the cube from different angles
      navigationDelegate: OrbitViewDelegate(boxFit: FskBoxFit.bestFit),
    );

    // Create the overlay in the upper left corner - Does NOT opt in to input
    final overlayLeft = StlOverlay(
      id: 'pip_left',
      left: 20,
      top: 20,
      screenSpaceSize: const Size(200, 200),
      interceptInput: false,
      navigationDelegate: OrbitViewDelegate(boxFit: FskBoxFit.bestFit),
    );

    // Add the overlays as layers to this scene
    addLayer(overlayRight);
    addLayer(overlayLeft);
  }
}
