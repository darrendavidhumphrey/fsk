import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fsk/fsk.dart';


/// A widget that renders a [FskSceneBase] and provides user interaction capabilities.
///
/// This widget builds upon [RenderToTextureCore] by adding a [GestureDetector],
/// a [Listener] for mouse events, and a [Focus] widget for keyboard events.
/// It forwards all user input to a [FskSceneNavigationDelegate] to control the scene.
class RenderToTexture extends StatefulWidget {
  /// The scene to be rendered.
  final FskSceneBase scene;
  final bool useAntiAliasing;

  const RenderToTexture({super.key, required this.scene,this.useAntiAliasing=false});

  @override
  RenderToTextureState createState() => RenderToTextureState();
}

class RenderToTextureState extends State<RenderToTexture> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // Set the scene on the delegate when the widget is first created.
    widget.scene.navigationDelegate?.setScene(widget.scene);
  }

  @override
  void didUpdateWidget(covariant RenderToTexture oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    // Dispose the FocusNode to prevent memory leaks.
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (details) => widget.scene.onScaleStart(details),
      onScaleUpdate: (details) => widget.scene.onScaleUpdate(details),
      onScaleEnd: (details) => widget.scene.onScaleEnd(details),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) => widget.scene.onPointerDown(event),
        onPointerMove: (event) => widget.scene.onPointerMove(event),
        onPointerUp: (event) => widget.scene.onPointerUp(event),
        onPointerSignal: (event) => widget.scene.onPointerSignal(event),
        onPointerCancel: (event) => widget.scene.onPointerCancel(event),
        child: MouseRegion(
          onEnter: (PointerEnterEvent event) => widget.scene.onPointerEnter(event),
          onExit: (PointerExitEvent event) => widget.scene.onPointerExit(event),
          onHover:(event) => widget.scene.onPointerHover(event),
          child: Focus(
            autofocus: true,
            focusNode: _focusNode,
            onKeyEvent: (node, event) => widget.scene.onKeyEvent(event),
            child: GPURenderWidget(
              scene: widget.scene,
              useAntiAliasing: widget.useAntiAliasing,
            ),
          ),
        ),
      ),
    );
  }
}
