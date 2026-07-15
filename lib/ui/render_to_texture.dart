import 'package:flutter/material.dart';
import 'package:fsk/fsk_scene.dart';
import 'package:fsk/ui/render_to_texture_core.dart';
import 'package:fsk/ui/navigation_delegates/scene_navigation_delegate.dart';

/// A widget that renders a [FskScene] and provides user interaction capabilities.
///
/// This widget builds upon [RenderToTextureCore] by adding a [GestureDetector],
/// a [Listener] for mouse events, and a [Focus] widget for keyboard events.
/// It forwards all user input to a [FskSceneNavigationDelegate] to control the scene.
class RenderToTexture extends StatefulWidget {
  /// The scene to be rendered.
  final FskScene scene;

  const RenderToTexture({
    super.key,
    required this.scene,
  });

  @override
  RenderToTextureState createState() =>
      RenderToTextureState();
}

class RenderToTextureState
    extends State<RenderToTexture> {
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
      onScaleStart: (details) =>
          widget.scene.navigationDelegate?.onScaleStart(details),
      onScaleUpdate: (details) =>
          widget.scene.navigationDelegate?.onScaleUpdate(details),
      onScaleEnd: (details) =>
          widget.scene.navigationDelegate?.onScaleEnd(details),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) =>
            widget.scene.navigationDelegate?.onPointerDown(event),
        onPointerMove: (event) =>
            widget.scene.navigationDelegate?.onPointerMove(event),
        onPointerUp: (event) =>
            widget.scene.navigationDelegate?.onPointerUp(event),
        onPointerSignal: (event) =>
            widget.scene.navigationDelegate?.onPointerSignal(event),
        onPointerCancel: (event) =>
            widget.scene.navigationDelegate?.onPointerCancel(event),
        child: Focus(
            autofocus: true,
            focusNode: _focusNode,
            onKeyEvent: (node, event) {
              if (widget.scene.navigationDelegate == null) {
                return KeyEventResult.handled;
              }
              return widget.scene.navigationDelegate!.onKeyEvent(event);
            },
            child: RenderToTextureCore(
                key: ValueKey(
                    '$widget.scene.renderToTextureId!+_RenderToTextureCore'),
                scene: widget.scene,
                navigationDelegate: widget.scene.navigationDelegate,
                child: SizedBox.expand())),
      ),
    );
  }
}
