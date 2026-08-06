import 'package:flutter/material.dart' hide Matrix4;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

class PbrModelScene extends FskFrameScene {
  PbrModelScene({super.navigationDelegate});

  @override
  Future<void> init() async {
    if (initStarted) return;
    await super.init();

    clearColor = const Color(0xFF101015);
    useBoxFitLayout = false; // Perspective 3D mode

    // Load the GLTF into our PBR model node in a single line
    final pbrModel = await FskPbrModel.loadFromAssets(
      assetFile: 'assets/3D/SciFiHelmet/glTF/SciFiHelmet.gltf',
      parentScene: this,
      sceneId: 'helmet',
      onModelLoaded: (model) {
        // Configure light position
        model.lightPosition = Vector3(200, 200, 0);

        // Optimized scale for standard orbit distance
        model.transformable.scale = Vector3.all(100.0);
      },
    );

    addNode(pbrModel);
    isReady = true;
  }
}