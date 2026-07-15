export declare class Sample08 {
    device: GPUDevice;
    context: GPUCanvasContext;
    pipeline: GPURenderPipeline;
    matBuf1: GPUBuffer;
    matBuf2: GPUBuffer;
    matBufViewProj: GPUBuffer;
    vertBuf: GPUBuffer;
    textureFormat: GPUTextureFormat;
    depthBuffer: GPUTexture;
    bindGroup1: GPUBindGroup;
    bindGroup2: GPUBindGroup;
    bgCamera: GPUBindGroup;
    rotationTurns: number;
    lastRenderTime: number;
    constructor(device: GPUDevice, context: GPUCanvasContext);
    update(dt: number): void;
    render(now: number): void;
    startRendering(): void;
}
//# sourceMappingURL=sample.d.ts.map