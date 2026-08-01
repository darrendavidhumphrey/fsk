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
    // This is now handled by the Mesh object calling uploadToGpu()
    _dataUploaded = true;
  }

  void rebuildPipeline() {
    if (!pipeLineNeedsRebuild && pipelineKey != null) return;

    final material = customMaterial ?? FskShaderMaterial.lighting;

    // Create a pipeline key for this shader and associated settings
    pipelineKey = PipelineKey(
      vertShaderName: material.vertShaderName,
      fragShaderName: material.fragShaderName,
      layoutName: "${material.vertShaderName}_${material.fragShaderName}_Pipeline",
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
      cullMode: gpu.CullMode.backFace,
    );

    uniforms = material.uniformsFactory(
      pipelineKey!.vertShader,
      pipelineKey!.fragShader,
    );
    
    layout = material.layout;
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
        uniforms!.samplerOptions = subMesh.textureInfo!.samplerOptions;
      }

      // If using lighting uniforms, apply material properties
      if (uniforms is OneLightUniforms) {
        final olu = uniforms as OneLightUniforms;
        final mat = subMesh.material ?? FSK().materials.getMaterial("default");
        olu.materialAmbient = mat.ambient;
        olu.materialDiffuse = mat.diffuse;
        olu.materialSpecular = mat.specular;
        olu.materialShininess = mat.shininess;
      } else if (uniforms is LightingUniforms) {
        final lu = uniforms as LightingUniforms;
        final mat = subMesh.material ?? FSK().materials.getMaterial("default");
        // Map GlMaterial to Kd (Diffuse)
        lu.kd = Vector3(mat.diffuse.r, mat.diffuse.g, mat.diffuse.b);
        lu.ld = Vector3(1.0, 1.0, 1.0); // Default light color
        lu.lightPos = Vector3(200, 200, 200);
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
