import 'package:flutter/material.dart' hide Matrix4;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' as vm;
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
        model.transformable.scale = vm.Vector3.all(1);
        model.centerModel();
        
        // Use the standard lighting uniforms since ObjModel defaults to LightingShader
        final uniforms = model.mesh.uniforms as LightingUniforms;
        uniforms.lightPos = vm.Vector3(500, 500, 500);
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

    final double cubeSize = 50;
    // Create the overlay in the upper right corner - Opts in to input
    final overlayRight = ViewCubeOverlay(
      id: 'pip_right',
      cubeSize: cubeSize,
      right: 20,
      top: 20,
      screenSpaceSize: const Size(300, 300),
      interceptInput: true,
      // Use an orbit delegate so we can see the cube from different angles
      navigationDelegate: ViewCubeNavigationDelegate(boxFit: FskBoxFit.bestFit),
    );

     var nav = overlayRight.navigationDelegate as ViewCubeNavigationDelegate;
     nav.setViewDistance(cubeSize * 2.5);


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
