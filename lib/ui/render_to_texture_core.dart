import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import '../fsk_singleton.dart';
import '../fsk_scene.dart';
import '../logging.dart';
import 'navigation_delegates/scene_navigation_delegate.dart';

class RenderToTextureCore extends StatefulWidget {
  final FskScene scene;
  final Widget? child;
  final FskSceneNavigationDelegate? navigationDelegate;

  const RenderToTextureCore({
    super.key,
    required this.scene,
    required this.navigationDelegate,
    this.child,
  });

  @override
  RenderToTextureCoreState createState() => RenderToTextureCoreState();
}

class RenderToTextureCoreState extends State<RenderToTextureCore>
    with WidgetsBindingObserver, TickerProviderStateMixin, LoggableClass {
  Size screenSize = Size.zero;
  Ticker? ticker;
  bool _tickerIsActive = false;

  // For web, track the initialization state to eliminate race conditions
  bool _isWebReady = false;
  bool _engineDataReady = false;

  // This key ensures the HtmlElement gets created again when the widget is ready
  int _webGenerationKey = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initRenderLoop();
  }

  void _initRenderLoop() async {
    // Make sure FSK is ready
    while (FSK().state != FskState.glInitialized) {
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
    }

    // Make sure texture is ready
    while (FSK().scenes[widget.scene] == null) {
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
    }

    if (mounted) {
      setState(() {
        _engineDataReady = true;
      });
    }

    // For non-web platforms start the ticker here
    // For web, wait until the window is ready
    if (!kIsWeb && mounted) {
      setState(() {
        _tickerIsActive = true;
      });
      ticker ??= createTicker(_onHardwareTick)..start();
    }
  }

  void _startWebTickerSafely() async {
    if (_tickerIsActive || !mounted) return;
    _tickerIsActive = true;

    if (mounted) {
      setState(() {
        _isWebReady = true;
        _webGenerationKey = 1;
      });

      ticker ??= createTicker(_onHardwareTick)..start();
      widget.scene.requestRepaint();
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
    onWindowResize();
  }

  void onWindowResize() {
    widget.scene.requestRepaint();
  }

  void _onHardwareTick(Duration elapsed) async {
    if (kIsWeb && (!_isWebReady)) return;

    if (widget.scene.frameProcessing) {
      return;
    }

    // FIX FOR COLD BOOT: Guard against setting dynamic/shifting constraints inside WebGL contexts.
    // If the browser window sizes are still settling down, skip the rendering loop pass.
    if (screenSize.width <= 0 || screenSize.height <= 0) {
      return;
    }

    widget.scene.setViewportSize(screenSize);

    if ((widget.navigationDelegate != null) &&
        (widget.navigationDelegate!.needsUpdate)) {
      // TODO: deprecated or not? widget.navigationDelegate.setNeedsUpdate(true);
      widget.navigationDelegate!.updateSceneMatrices();
    }
    await widget.scene.renderSceneToTexture();

    if (mounted) {
      if (!kIsWeb) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        FlutterAngleTexture? texture = FSK().scenes[widget.scene];

        if ((!_engineDataReady) || (texture == null)) {
          return const Center(child: CircularProgressIndicator());
        }

        // Continuously update screen size in case it changed.
        // This ensures the viewport is correct for constructing GL matrices
        screenSize = Size(constraints.maxWidth, constraints.maxHeight);
        // TODO! widget.navigationDelegate.setNeedsUpdate(true);

        // On web, only start the ticker once size is non-zero
        if (kIsWeb && constraints.maxWidth > 0 && constraints.maxHeight > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _startWebTickerSafely();
            }
          });
        }

        final String elementKey =
            'canvas-surface-${texture.textureId}-$_webGenerationKey';

        return Stack(
          children: [
            SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: kIsWeb
                  ? HtmlElementView(
                      key: ValueKey(elementKey),
                      viewType: texture.textureId.toString(),
                    )
                  : Texture(
                      key: ValueKey(texture.textureId),
                      textureId: texture.textureId,
                      filterQuality: FilterQuality.medium,
                    ),
            ),
            if (widget.child != null) widget.child!,
          ],
        );
      },
    );
  }
}
