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

    clearColor = const Color(0xFF101015);
    useBoxFitLayout = false; // Perspective 3D mode

    // Create our new PBR-specialized node
    pbrModel = FskPbrModel('helmet', this);

    // Load the GLTF into our PBR model node
    await FskGltfLoader.load('assets/3D/SciFiHelmet/glTF/SciFiHelmet.gltf', this,
        rootNode: pbrModel);

    // Configure light position once on the node
    pbrModel.lightPosition = Vector3(200, 200, 0);

    // Optimized scale for standard orbit distance
    pbrModel.transformable.scale = Vector3.all(100.0);

    addNode(pbrModel);
    isReady = true;
  }
}
