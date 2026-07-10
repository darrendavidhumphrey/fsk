import 'package:flutter/material.dart';
import 'package:fsk/ui/render_to_texture.dart';
import '../indexed_stack_scene.dart';

class IndexedSceneViewer extends StatefulWidget {
  final IndexedStackScene scene;

  const IndexedSceneViewer({super.key, required this.scene});

  @override
  State<IndexedSceneViewer> createState() => _IndexedSceneViewerState();
}

class _IndexedSceneViewerState extends State<IndexedSceneViewer> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.scene,
      builder: (BuildContext context, Widget? child) {


        // 2. Refresh and cleanly render the Texture view once initialized
        return RenderToTexture(
          scene: widget.scene.currentScene(),
        );
      },
    );
  }
}