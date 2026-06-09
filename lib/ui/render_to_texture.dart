import 'package:flutter/material.dart';
import 'package:fsg/scene.dart';
import 'package:fsg/ui/render_to_texture_core.dart';
import 'package:fsg/ui/navigation_delegates/scene_navigation_delegate.dart';

/// A widget that renders a [Scene] and provides user interaction capabilities.
///
/// This widget builds upon [RenderToTextureCore] by adding a [GestureDetector],
/// a [Listener] for mouse events, and a [Focus] widget for keyboard events.
/// It forwards all user input to a [SceneNavigationDelegate] to control the scene.
class RenderToTexture extends StatefulWidget {
  /// The scene to be rendered.
  final Scene scene;

  /// The delegate responsible for handling user input and navigating the scene.
  final SceneNavigationDelegate navigationDelegate;

  const RenderToTexture({
    super.key,
    required this.scene,
    required this.navigationDelegate,
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
    widget.navigationDelegate.setScene(widget.scene);
  }

  @override
  void didUpdateWidget(covariant RenderToTexture oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the scene or delegate changes, update the delegate.
    if (widget.scene != oldWidget.scene ||
        widget.navigationDelegate != oldWidget.navigationDelegate) {
      widget.navigationDelegate.setScene(widget.scene);
    }
  }

  @override
  void dispose() {
    // Dispose the FocusNode to prevent memory leaks.
    widget.navigationDelegate.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => widget.navigationDelegate.onPointerDown(event),
      onPointerMove: (event) => widget.navigationDelegate.onPointerMove(event),
      onPointerUp: (event) => widget.navigationDelegate.onPointerUp(event),
      onPointerSignal: (event) => widget.navigationDelegate.onPointerSignal(event),
      onPointerCancel: (event) =>
          widget.navigationDelegate.onPointerCancel(event),
      child: Focus(
        autofocus: true,
        focusNode: _focusNode,
        onKeyEvent: (node, event) =>
            widget.navigationDelegate.onKeyEvent(event),
        child: RenderToTextureCore(
            key: ValueKey('$widget.scene.renderToTextureId!+_RenderToTextureCore'),
            scene: widget.scene,
            navigationDelegate: widget.navigationDelegate,
            child: SizedBox.expand()
        )
      ),
    );
  }
}
