import 'package:flutter/material.dart' hide Matrix4;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

class PbrModelScene extends FskFrameScene {
  late FskPbrModel pbrModel;

  PbrModelScene({super.navigationDelegate});

  @override
  Future<void> init() async {
    if (initStarted) return;
    await super.init();
    logInfo("PbrModelScene.init: Starting...");
    clearColor = const Color(0xFF101015);
    useBoxFitLayout = false; // Perspective 3D mode

    try {
      // Create our new PBR-specialized node
      pbrModel = FskPbrModel('helmet', this);
      
      // Configure light position once on the node
      pbrModel.lightPosition = Vector3(200, 200, 0);

      // Load the GLTF into our PBR model node
      logInfo("PbrModelScene.init: loading GLTF model...");
      await FskGltfLoader.load(
        'assets/3D/SciFiHelmet/glTF/SciFiHelmet.gltf', 
        this, 
        rootNode: pbrModel
      );


      // Optimized scale for standard orbit distance
      pbrModel.transformable.scale = Vector3.all(100.0);
      
      addNode(pbrModel);
      
      logInfo("PbrModelScene.init: Done.");
      isReady = true;
    } catch (e, s) {
      logError("Error loading PBR model: $e\n$s");
      isReady = true;
    }
  }
}
