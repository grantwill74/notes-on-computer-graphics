export declare function genXorTexture(device: GPUDevice, width?: number, height?: number): GPUTexture;
export declare function initSample05Pipeline(device: GPUDevice, context: GPUCanvasContext): GPURenderPipeline;
export declare function initSample05Verts(device: GPUDevice): GPUBuffer;
export declare function createTextureAndSamplerBindGroup(device: GPUDevice, pipeline: GPURenderPipeline, tex: GPUTexture, samp: GPUSampler): GPUBindGroup;
export declare function initSample05OffsetBg(device: GPUDevice, pipeline: GPURenderPipeline, offset: [number, number]): GPUBindGroup;
export declare function renderSample05(device: GPUDevice, context: GPUCanvasContext, pipeline: GPURenderPipeline, vertBuf: GPUBuffer, texBg: GPUBindGroup, offsetBg: GPUBindGroup): void;
export declare function loadTexture(device: GPUDevice, url: URL): Promise<GPUTexture>;
//# sourceMappingURL=sample.d.ts.map