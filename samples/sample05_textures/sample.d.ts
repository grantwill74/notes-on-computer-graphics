export declare function genXorTexture(device: GPUDevice, width?: number, height?: number): GPUTexture;
export declare function initSample05Pipeline(device: GPUDevice, context: GPUCanvasContext): GPURenderPipeline;
export declare function initSample05Verts(device: GPUDevice): GPUBuffer;
export declare function createTextureAndSamplerBindGroup(device: GPUDevice, pipeline: GPURenderPipeline, tex: GPUTexture, samp: GPUSampler): GPUBindGroup;
export declare function renderSample05(device: GPUDevice, context: GPUCanvasContext, pipeline: GPURenderPipeline, vertBuf: GPUBuffer, bg: GPUBindGroup): void;
//# sourceMappingURL=sample.d.ts.map