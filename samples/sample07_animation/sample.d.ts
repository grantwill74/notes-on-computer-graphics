export declare class Sample07 {
    device: GPUDevice;
    context: GPUCanvasContext;
    pipeline: GPURenderPipeline;
    matBuf: GPUBuffer;
    vertBuf: GPUBuffer;
    textureFormat: GPUTextureFormat;
    depthBuffer: GPUTexture;
    bindGroup: GPUBindGroup;
    rotationTurns: number;
    constructor(device: GPUDevice, context: GPUCanvasContext);
    update(): void;
    startUpdating(): void;
    render(): void;
    startRendering(): void;
}
//# sourceMappingURL=sample.d.ts.map