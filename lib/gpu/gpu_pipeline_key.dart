import 'package:flutter_gpu/gpu.dart' as gpu;
import '../fsk_singleton.dart';

class PipelineKey {
  // 1. Shaders
  final String vertShaderName;
  final String fragShaderName;
  late gpu.Shader vertShader;
  late gpu.Shader fragShader;

  // 2. Depth State
  final bool depthTestEnabled;
  final bool depthWriteEnabled;
  final gpu.CompareFunction depthCompareOperation;

  // 3. Texturing / Material State
  // (In modern GPU design, changing textures doesn't require a new pipeline,
  // but toggling a texture ON/OFF might swap shader logic or input requirements)
  final bool texturingEnabled;

  // 4. Blending Configuration
  final bool blendEnabled;
  final gpu.BlendFactor srcColorFactor;
  final gpu.BlendFactor dstColorFactor;
  final gpu.BlendFactor srcAlphaFactor;
  final gpu.BlendFactor dstAlphaFactor;
  final gpu.BlendOperation colorBlendOp;
  final gpu.BlendOperation alphaBlendOp;

  // 5. Common Primitive States
  final gpu.WindingOrder windingOrder;
  final gpu.CullMode cullMode;

  PipelineKey({
    required this.vertShaderName,
    required this.fragShaderName,
    this.depthTestEnabled = false,
    this.depthWriteEnabled = false,
    this.depthCompareOperation = gpu.CompareFunction.less,
    this.texturingEnabled = false,
    this.blendEnabled = true,
    this.srcColorFactor = gpu.BlendFactor.sourceAlpha,
    this.dstColorFactor = gpu.BlendFactor.oneMinusSourceAlpha,
    this.srcAlphaFactor = gpu.BlendFactor.one,
    this.dstAlphaFactor = gpu.BlendFactor.oneMinusSourceAlpha,
    this.colorBlendOp = gpu.BlendOperation.add,
    this.alphaBlendOp = gpu.BlendOperation.add,
    this.windingOrder = gpu.WindingOrder.counterClockwise,
    this.cullMode = gpu.CullMode.none,
  }) {
    var v = FSK().shaderLibrary[vertShaderName];
    var f = FSK().shaderLibrary[fragShaderName];

    assert(v != null, "Vert Shader not found: $vertShaderName");
    assert(f != null, "Frag Shader not found: $fragShaderName");
    vertShader = v!;
    fragShader = f!;
  }

  void applyPipelineStates(gpu.RenderPass renderPass) {
    // 1. Configure dynamic primitive attributes
    renderPass.setCullMode(cullMode);
    renderPass.setWindingOrder(windingOrder);

    // 2. Configure dynamic depth testing structures
    renderPass.setDepthWriteEnable(depthWriteEnabled);
    if (depthTestEnabled) {
      renderPass.setDepthCompareOperation(depthCompareOperation);
    } else {
      // Bypasses depth checks when explicitly requested off by the node layout
      renderPass.setDepthCompareOperation(gpu.CompareFunction.always);
    }

    // 3. Configure dynamic blending equations
    renderPass.setColorBlendEnable(blendEnabled);
    if (blendEnabled) {
      renderPass.setColorBlendEquation(
        gpu.ColorBlendEquation(
          colorBlendOperation: colorBlendOp,
          sourceColorBlendFactor: srcColorFactor,
          destinationColorBlendFactor: dstColorFactor,
          alphaBlendOperation: alphaBlendOp,
          sourceAlphaBlendFactor: srcAlphaFactor,
          destinationAlphaBlendFactor: dstAlphaFactor,
        ),
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PipelineKey &&
          runtimeType == other.runtimeType &&
          vertShaderName == other.vertShaderName &&
          fragShaderName == other.fragShaderName &&
          depthTestEnabled == other.depthTestEnabled &&
          depthWriteEnabled == other.depthWriteEnabled &&
          depthCompareOperation == other.depthCompareOperation &&
          texturingEnabled == other.texturingEnabled &&
          blendEnabled == other.blendEnabled &&
          srcColorFactor == other.srcColorFactor &&
          dstColorFactor == other.dstColorFactor &&
          srcAlphaFactor == other.srcAlphaFactor &&
          dstAlphaFactor == other.dstAlphaFactor &&
          colorBlendOp == other.colorBlendOp &&
          alphaBlendOp == other.alphaBlendOp &&
          windingOrder == other.windingOrder &&
          cullMode == other.cullMode;

  @override
  int get hashCode => Object.hashAll([
    vertShaderName,
    fragShaderName,
    depthTestEnabled,
    depthWriteEnabled,
    depthCompareOperation,
    texturingEnabled,
    blendEnabled,
    srcColorFactor,
    dstColorFactor,
    srcAlphaFactor,
    dstAlphaFactor,
    colorBlendOp,
    alphaBlendOp,
    windingOrder,
    cullMode,
  ]);
}

const gpu.VertexLayout v3t2n3c4Layout = gpu.VertexLayout(
  buffers: [
    // Slot 0: Our main interleaved vertex buffer
    gpu.VertexBuffer(
      strideInBytes: 48, // 12 total floats * 4 bytes per element
      stepMode: gpu.VertexStepMode.vertex,
      attributes: [
        // 📍 Position Attribute (vec3 / float32x3)
        // Takes 12 bytes. Starts at byte 0.
        gpu.VertexAttribute(
          name:
              'aVertexPosition', // Must exactly match the input name in your vertex shader
          format: gpu.VertexFormat.float32x3,
          offsetInBytes: 0,
        ),

        // 📍 Texture Coordinate Attribute (vec2 / float32x2)
        // Takes 8 bytes. Starts at byte 12 (after position).
        gpu.VertexAttribute(
          name: 'aTextureCoord',
          format: gpu.VertexFormat.float32x2,
          offsetInBytes: 12,
        ),

        // 📍 Normal Attribute (vec3 / float32x3)
        // Takes 12 bytes. Starts at byte 20 (12 + 8).
        gpu.VertexAttribute(
          name: 'aVertexNormal',
          format: gpu.VertexFormat.float32x3,
          offsetInBytes: 20,
        ),

        // 📍 Color Attribute (vec4 / float32x4)
        // Takes 16 bytes. Starts at byte 32 (20 + 12).
        gpu.VertexAttribute(
          name: 'aVertexColor',
          format: gpu.VertexFormat.float32x4,
          offsetInBytes: 32,
        ),
      ],
    ),
  ],
);

// Removing the unreferenced attributes satisfies flutter_gpu
const gpu.VertexLayout v3t2Layout = gpu.VertexLayout(
  buffers: [
    gpu.VertexBuffer(
      strideInBytes:
          48, // All Vertex Buffers have all 12 component floats
      stepMode: gpu.VertexStepMode.vertex,
      attributes: [
        gpu.VertexAttribute(
          name: 'aVertexPosition', // Present in shader execution graph
          format: gpu.VertexFormat.float32x3,
          offsetInBytes: 0,
        ),
        gpu.VertexAttribute(
          name: 'aTextureCoord', // Present in shader execution graph
          format: gpu.VertexFormat.float32x2,
          offsetInBytes: 12,
        ),

      ],
    ),
  ],
);

const gpu.VertexLayout v3n3Layout = gpu.VertexLayout(
  buffers: [
    gpu.VertexBuffer(
      strideInBytes: 48,
      stepMode: gpu.VertexStepMode.vertex,
      attributes: [
        gpu.VertexAttribute(
          name: 'aVertexPosition',
          format: gpu.VertexFormat.float32x3,
          offsetInBytes: 0,
        ),
        gpu.VertexAttribute(
          name: 'aVertexNormal',
          format: gpu.VertexFormat.float32x3,
          offsetInBytes: 20,
        ),
      ],
    ),
  ],
);

const gpu.VertexLayout v3n3c4Layout = gpu.VertexLayout(
  buffers: [
    gpu.VertexBuffer(
      strideInBytes: 48,
      stepMode: gpu.VertexStepMode.vertex,
      attributes: [
        gpu.VertexAttribute(
          name: 'aVertexPosition',
          format: gpu.VertexFormat.float32x3,
          offsetInBytes: 0,
        ),
        gpu.VertexAttribute(
          name: 'aVertexNormal',
          format: gpu.VertexFormat.float32x3,
          offsetInBytes: 20,
        ),
        gpu.VertexAttribute(
          name: 'aVertexColor',
          format: gpu.VertexFormat.float32x4,
          offsetInBytes: 32,
        ),
      ],
    ),
  ],
);

class PipelineCache {
  final Map<PipelineKey, gpu.RenderPipeline> _cache = {};

  PipelineCache();

  void clearCache() {
    _cache.clear();
  }

  // Activate an existing pipeline (or instantiate a new one)
  // Then bind it to the renderpass and set the pipeline states
  gpu.RenderPipeline activate(
    PipelineKey key,
    gpu.RenderPass renderPass,
    gpu.VertexLayout layout,
  ) {
    gpu.RenderPipeline? pipeline = _cache[key];

    if (pipeline == null) {
      pipeline = gpu.gpuContext.createRenderPipeline(
        key.vertShader,
        key.fragShader,
        vertexLayout: layout,
      );

      _cache[key] = pipeline;
    }
    renderPass.bindPipeline(pipeline);

    key.applyPipelineStates(renderPass);

    return pipeline;
  }
}
