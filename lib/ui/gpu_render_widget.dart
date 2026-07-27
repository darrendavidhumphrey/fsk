import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';

class GPURenderWidget extends StatefulWidget {
  final FskScene scene;
  const GPURenderWidget({required this.scene, super.key});

  @override
  State<GPURenderWidget> createState() => _GPURenderWidgetState();
}

class _GPURenderWidgetState extends State<GPURenderWidget> with SingleTickerProviderStateMixin {

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder to dynamically read out the exact size allocated by the parent constraints
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {

            // Rebuild VBOs and pipelines before drawing
            if (widget.scene.isReady) {
              widget.scene.rebuildGeometry();
            }

            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight), // Explicitly fills layout bounds
              painter: FskScenePainter(
                scene: widget.scene,
              ),
            );
          },
        );
      },
    );
  }
}

class FskScenePainter extends CustomPainter {
  final FskScene scene;

  FskScenePainter({
    required this.scene,
  });

  void blitImage(Canvas canvas, Size size,gpu.Texture texture) {
    final uiImage = texture.asImage();
    // 5. Blit and scale image properties directly inside our custom canvas space
    canvas.drawImageRect(
      uiImage,
      Rect.fromLTWH(0, 0, texture.width.toDouble(), texture.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {

    // Early out if scene is not ready
    // TODO: Defer to a loading widget here...
    if (scene.isReady == false) {
      return;
    }

    // Recalculate view
    scene.updateRenderTargetSize(size.width.toInt(), size.height.toInt());

    //  reallocate backing texture
    scene.allocateRenderTarget();

    // Create per-scene gpu command buffer, render pass, and frameTransients (uniforms?)
    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final renderPass = commandBuffer.createRenderPass(scene.renderTarget!);
    final gpu.HostBuffer frameTransients = gpu.gpuContext.createHostBuffer();

    // Inform scene of current viewport size
    scene.viewportSize = size;

    // Draw the scene, accumulating commands into commandBuffer via renderPass
    print("Start of draw scene");
    scene.drawScene(renderPass,frameTransients);
    print("After draw scene");
    // Submit commands to GPU to draw
    commandBuffer.submit();

    // Clear any buffers that were disposed during the rebuild
    scene.clearRetainedBuffers();

    blitImage(canvas, size, scene.texture!);
  }

  @override
  bool shouldRepaint(covariant FskScenePainter oldDelegate) {
    return oldDelegate.scene != scene;
  }
}