import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../fsg_singleton.dart';
import '../scene.dart';
import '../logging.dart';

/// A core stateful widget that manages the lifecycle of rendering a [Scene] to a texture.
///
/// This widget handles:
/// - Creating and managing a [Ticker] to drive the render loop.
/// - Using a [LayoutBuilder] to get the viewport size.
/// - Using a [VisibilityDetector] to automatically pause the scene when it's not visible.
/// - Registering the scene with the [FSG] singleton and getting a texture ID.
/// - Displaying the final texture via a [Texture] widget.
///
/// This widget is not intended for direct use. It is wrapped by [RenderToTexture]
/// and [InteractiveRenderToTexture] to provide a simpler public API.
class RenderToTextureCore extends StatefulWidget {
  final Scene scene;
  final bool automaticallyPause;
  final Widget? child;

  const RenderToTextureCore({super.key,
    required this.scene,
    this.automaticallyPause = true,
    this.child,
  });

  @override
  RenderToTextureCoreState createState() => RenderToTextureCoreState();
}

class RenderToTextureCoreState extends State<RenderToTextureCore>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin, LoggableClass {
  Size screenSize = Size.zero;
  bool windowResized = false;
  Ticker? ticker;
  final Key _visibilityKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.automaticallyPause) {
      widget.scene.isPaused = true;
    }
  }

  @override
  void dispose() {
    ticker?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Triggers a repaint and viewport resize on window metric changes (like rotation).
    onWindowResize();
  }

  void onWindowResize() {
    windowResized = true;
    widget.scene.requestRepaint();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FSG().frameCounter,
      builder: (context, child) {
        return VisibilityDetector(
          key: _visibilityKey,
          onVisibilityChanged: (visibilityInfo) {
            if (widget.automaticallyPause) {
              bool visible = (visibilityInfo.visibleFraction > 0);
              widget.scene.isPaused = !visible;
              if (visible) {
                widget.scene.requestRepaint();
              }
            }
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              FlutterAngleTexture? texture = FSG().scenes[widget.scene];

              if (texture != null) {
                bool firstPaint = !widget.scene.isInitialized;
                if (firstPaint) {
                  // If this is the first time painting, initialize the scene and start the ticker.
                  FSG().initScene(widget.scene);
                  ticker = createTicker(widget.scene.renderSceneToTexture)
                    ..start();
                }

                if (firstPaint || windowResized) {
                  // Update the scene's viewport size if it's the first paint or the window resized.
                  windowResized = false;
                  screenSize = Size(constraints.maxWidth, constraints.maxHeight);
                  widget.scene.setViewportSize(screenSize);
                }

                final textureWidget = Texture(
                  textureId: texture.textureId,
                  filterQuality: FilterQuality.medium,
                );

                // If a child is provided (e.g., gesture detectors), stack it on top.
                if (widget.child != null) {
                  return Stack(children: [textureWidget, widget.child!]);
                }
                return textureWidget;
              } else {
                // If the texture has not yet been allocated by FSG, schedule a post-frame
                // callback to register the scene. This prevents calling setState during build.
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  FSG().registerSceneAndAllocateTexture(widget.scene);
                  // Increment counter to trigger a rebuild once the texture is ready.
                  FSG().frameCounter.increment();
                });
                return Container(); // Return an empty container while waiting.
              }
            },
          ),
        );
      },
    );
  }
}
