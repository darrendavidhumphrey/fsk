import 'package:vector_math/vector_math.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import '../shaders/base_uniforms.dart';
import 'fsk_renderer_base.dart';

class SubMesh {
  final int indexCount;
  final int firstIndex;
  final String? materialName;
  FskTextureInfo? textureInfo;
  GlMaterial? material;

  SubMesh({
    required this.indexCount,
    required this.firstIndex,
    this.materialName,
    this.textureInfo,
    this.material,
  });
}

class FskIndexedMeshRenderer extends FskRendererBase {
  BaseUniforms? uniforms;
  PipelineKey? pipelineKey;

  bool _dataUploaded = false;
  bool isValid = false;
  bool pipeLineNeedsRebuild = true;

  String vertShaderName = "OneLightVertex";
  String fragShaderName = "OneLightFragment";
  gpu.VertexLayout layout = v3t2n3Layout;

  /// The vertex buffer object that holds the geometry for rendering.
  final FskVertexBuffer _vbo = FskVertexBuffer();
  final FskIndexBuffer _ibo = FskIndexBuffer();

  final List<SubMesh> _subMeshes = [];

  FskVertexBuffer get vbo => _vbo;
  FskIndexBuffer get ibo => _ibo;

  /////////////////////////////////////////////////////////////////////////////
  // Public API
  /////////////////////////////////////////////////////////////////////////////

  void clearSubMeshes() {
    _subMeshes.clear();
    _dataUploaded = false;
  }

  void addSubMesh(SubMesh subMesh) {
    _subMeshes.add(subMesh);
  }

  void finalizeData() {
    _vbo.uploadData();
    _ibo.uploadData();
    _dataUploaded = true;
  }

  void rebuildPipeline() {
    if (!pipeLineNeedsRebuild && pipelineKey != null) return;

    // Create a pipeline key for this shader and associated settings
    pipelineKey = PipelineKey(
      vertShaderName: vertShaderName,
      fragShaderName: fragShaderName,
      layoutName: "IndexedMeshLayout",
      depthTestEnabled: true,
      depthWriteEnabled: true,
      depthCompareOperation: gpu.CompareFunction.less,
      texturingEnabled: true,
      srcColorFactor: gpu.BlendFactor.sourceAlpha,
      dstColorFactor: gpu.BlendFactor.oneMinusSourceAlpha,
      srcAlphaFactor: gpu.BlendFactor.one,
      dstAlphaFactor: gpu.BlendFactor.oneMinusSourceAlpha,
      colorBlendOp: gpu.BlendOperation.add,
      alphaBlendOp: gpu.BlendOperation.add,
      windingOrder: gpu.WindingOrder.counterClockwise,
      cullMode: gpu.CullMode.none,
    );

    if (fragShaderName.contains("OneLight")) {
      uniforms = OneLightUniforms(
        vertexShader: pipelineKey!.vertShader,
        fragmentShader: pipelineKey!.fragShader,
      );
      layout = v3t2n3Layout;
    } else {
      uniforms = SimpleTextureUniforms(
        vertexShader: pipelineKey!.vertShader,
        fragmentShader: pipelineKey!.fragShader,
      );
      layout = v3t2Layout;
    }
    pipeLineNeedsRebuild = false;
  }

  /////////////////////////////////////////////////////////////////////////////
  // Constructor
  /////////////////////////////////////////////////////////////////////////////
  FskIndexedMeshRenderer();

  void _checkIsValid() {
    isValid = _dataUploaded && _subMeshes.isNotEmpty;
  }

  @override
  void draw(
      gpu.RenderPass renderPass,
      gpu.HostBuffer transients,
      Matrix4 pMatrix,
      Matrix4 mvMatrix,
      ) {
    _checkIsValid();
    if (!isValid) return;

    rebuildPipeline();

    FSK().activatePipeline(
      pipelineKey!,
      renderPass,
      layout,
    );

    _vbo.bind(renderPass);

    for (var subMesh in _subMeshes) {
      if (subMesh.textureInfo != null) {
        uniforms!.texture = subMesh.textureInfo!.texture;
      }

      // If using lighting uniforms, apply material properties
      if (uniforms is OneLightUniforms) {
        final olu = uniforms as OneLightUniforms;
        final mat = subMesh.material ?? FSK().materials.getMaterial("default");
        olu.materialAmbient = mat.ambient;
        olu.materialDiffuse = mat.diffuse;
        olu.materialSpecular = mat.specular;
        olu.materialShininess = mat.shininess;
      }

      uniforms!.mvMatrix = mvMatrix.clone();
      uniforms!.pMatrix = pMatrix.clone();
      uniforms!.bind(renderPass, transients);

      // Rebind the index buffer with the correct offset for each sub-mesh
      _ibo.bind(renderPass, offsetInIndices: subMesh.firstIndex);
      _ibo.drawTrianglesIndexed(
        renderPass,
        count: subMesh.indexCount,
      );
    }
  }
}
