import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import '../fsg_singleton.dart';
import '../scene.dart';
import '../logging.dart';

class RenderToTextureCore extends StatefulWidget {
  final Scene scene;
  final Widget? child;

  const RenderToTextureCore({
    super.key,
    required this.scene,
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
  bool _isWebReady = false;
  bool _webLayoutSettled = false;
  bool _engineDataReady = false;
  int _webGenerationKey = 0;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initRenderLoop();
  }

  void _initRenderLoop() async {

    // Make sure FSG is ready
    while (FSG().state != FsgState.glInitialized) {
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
    }

    // Make sure texture is ready
    while (FSG().scenes[widget.scene] == null) {
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
    }

    if (mounted) {
      setState(() {
        _engineDataReady = true;
      });
    }

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
    if (kIsWeb && (!_isWebReady || !_webLayoutSettled)) return;

    if (widget.scene.frameProcessing) {
      return;
    }

    // FIX FOR COLD BOOT: Guard against setting dynamic/shifting constraints inside WebGL contexts.
    // If the browser window sizes are still settling down, skip the rendering loop pass.
    if (screenSize.width <= 0 || screenSize.height <= 0) {
      return;
    }

    widget.scene.setViewportSize(screenSize);

    await widget.scene.renderSceneToTexture();

    if (mounted) {
      if (!kIsWeb) {
        setState(() {
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_engineDataReady) {
          return const Center(child: CircularProgressIndicator());
        }

        FlutterAngleTexture? texture = FSG().scenes[widget.scene];
        if (texture == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final double currentWidth = constraints.maxWidth;
        final double currentHeight = constraints.maxHeight;

        // Continuously update tracking parameters outside mutation callbacks
        screenSize = Size(currentWidth, currentHeight);

        if (kIsWeb && currentWidth > 0 && currentHeight > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (!_webLayoutSettled) {
                setState(() {
                  _webLayoutSettled = true;
                });
              }
              _startWebTickerSafely();
            }
          });
        }

        final String boundaryKey = 'canvas-boundary-${texture.textureId}-$_webGenerationKey';
        final String elementKey = 'canvas-surface-${texture.textureId}-$_webGenerationKey';

        return Stack(
          children: [
            SizedBox(
              width: currentWidth,
              height: currentHeight,
              child: kIsWeb
                  ? RepaintBoundary(
                key: ValueKey(boundaryKey),
                child: HtmlElementView(
                  key: ValueKey(elementKey),
                  viewType: texture.textureId.toString(),
                ),
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
