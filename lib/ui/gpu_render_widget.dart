import 'dart:typed_data';
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart';

class GPURenderWidget extends StatefulWidget {
  final FskScene scene;
  const GPURenderWidget({required this.scene, super.key});

  @override
  State<GPURenderWidget> createState() => _GPURenderWidgetState();
}

class _GPURenderWidgetState extends State<GPURenderWidget> with SingleTickerProviderStateMixin {
  gpu.RenderPipeline? _pipeline;
  gpu.Texture? _texture;
  gpu.RenderTarget? _renderTarget;
  gpu.UniformSlot? _mvpUniformSlot;

  late AnimationController _animationController;
  bool _isInitialized = false;

  // Track the current texture dimensions to avoid unneeded recreations
  int _currentWidth = 0;
  int _currentHeight = 0;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _initializeStaticGPUResources();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 1. Initialize items that do NOT change when the widget changes sizes
  Future<void> _initializeStaticGPUResources() async {
    final vertexShader = FSK().shaderLibrary['CheckerBoardVertex']!;
    final fragmentShader = FSK().shaderLibrary['CheckerBoardFragment']!;

    _pipeline = gpu.gpuContext.createRenderPipeline(
      vertexShader,
      fragmentShader,
    );

    _mvpUniformSlot = vertexShader.getUniformSlot('UniformBlock');

    setState(() {
      _isInitialized = _pipeline != null && _mvpUniformSlot != null;
    });
  }

  // 2. Dynamic resize function called safely when the parent layout triggers bounds changes
  void _updateRenderTargetSize(int width, int height) {
    if (width <= 0 || height <= 0) return;
    if (_currentWidth == width && _currentHeight == height && _renderTarget != null) return;

    _currentWidth = width;
    _currentHeight = height;

    // Allocate a brand new texture sized to match the physical container exactly
    _texture = gpu.gpuContext.createTexture(
      gpu.StorageMode.hostVisible,
      _currentWidth,
      _currentHeight,
    );

    if (_texture != null) {
      // TODO: Pass in clear color from scene

      // TODO: This also needs to happen when the clearColor changes
      Vector4 clearValue = Vector4(1.0, 1.0, 1.0, 1.0);
      _renderTarget = gpu.RenderTarget.singleColor(
        gpu.ColorAttachment(texture: _texture!, clearValue: clearValue),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // 3. Use LayoutBuilder to dynamically read out the exact size allocated by the parent constraints
    return LayoutBuilder(
      builder: (context, constraints) {
        // Enforce physical constraints integers
        final int targetWidth = constraints.maxWidth.toInt();
        final int targetHeight = constraints.maxHeight.toInt();

        // Safe recalculation step before dispatching paint frames
        _updateRenderTargetSize(targetWidth, targetHeight);

        if (_renderTarget == null || _texture == null) {
          return const SizedBox.shrink();
        }

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight), // Explicitly fills layout bounds
              painter: FskScenePainter(
                scene: widget.scene,
                pipeline: _pipeline!,
                renderTarget: _renderTarget!,
                texture: _texture!,
                mvpSlot: _mvpUniformSlot!,
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
  final gpu.RenderPipeline pipeline;
  final gpu.RenderTarget renderTarget;
  final gpu.Texture texture;
  final gpu.UniformSlot mvpSlot;

  FskScenePainter({
    required this.scene,
    required this.pipeline,
    required this.renderTarget,
    required this.texture,
    required this.mvpSlot,
  });

  void finishFrame(gpu.CommandBuffer commandBuffer, gpu.RenderTarget renderTarget) {
    commandBuffer.submit();
  }

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
    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final renderPass = commandBuffer.createRenderPass(renderTarget);

    renderPass.bindPipeline(pipeline);


    // 4. Added perspective correction adjustment rule inside matrix initialization sequence
    // This stops the triangle from getting stretched or squished when resizing the window aspect ratio
    final double aspectRatio = size.width / size.height;
    final Matrix4 projection = Matrix4.identity();
    projection.scaleByVector3(Vector3(1.0 / aspectRatio, 1.0, 1.0));

    // Combine rotation and our aspect projection matrices
    final Matrix4 rotationMatrix = Matrix4.identity();
    final Matrix4 mvpMatrix = projection * rotationMatrix;

    final Float32List matrixBytes = Float32List(16);
    mvpMatrix.copyIntoArray(matrixBytes);

    final gpu.HostBuffer transients = gpu.gpuContext.createHostBuffer();
    final gpu.BufferView uniformBufferView = transients.emplace(ByteData.sublistView(matrixBytes));

    renderPass.setWindingOrder(gpu.WindingOrder.counterClockwise);
    renderPass.setCullMode(gpu.CullMode.none);


    scene.drawScene(renderPass,size);

    finishFrame(commandBuffer, renderTarget);
    blitImage(canvas, size, texture);

  }

  @override
  bool shouldRepaint(covariant FskScenePainter oldDelegate) {
    return oldDelegate.pipeline != pipeline ||
        oldDelegate.renderTarget != renderTarget ||
        oldDelegate.texture != texture;
  }
}