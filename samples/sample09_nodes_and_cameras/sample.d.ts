import { mat4, vec3 } from "gl-matrix";
export declare class SimpleNode {
    yaw: number;
    pitch: number;
    pos: vec3;
    scale: vec3;
    matrix: mat4;
    matrixBuf: GPUBuffer;
    matrixBg: GPUBindGroup;
    mesh: GPUBuffer | undefined;
    name: string;
    constructor(name: string, device: GPUDevice, layout: GPUBindGroupLayout);
    vertData: GPUBuffer | undefined;
    updateMatrix(device: GPUDevice): void;
    forward(): vec3;
    right(): vec3;
    up(): vec3;
}
export declare class Keys {
    down: Set<string>;
    constructor();
    isDown(code: string): boolean;
}
export declare class Sample09 {
    device: GPUDevice;
    context: GPUCanvasContext;
    cubeBuf: GPUBuffer;
    cube1: SimpleNode;
    cube2: SimpleNode;
    cube3: SimpleNode;
    camera: SimpleNode;
    projection: mat4;
    view: mat4;
    viewProj: mat4;
    matViewProj: GPUBuffer;
    bgMatViewProj: GPUBindGroup;
    lastRender: number;
    canvasFormat: GPUTextureFormat;
    pipeline: GPURenderPipeline;
    depthBuffer: GPUTexture;
    keys: Keys;
    constructor(device: GPUDevice, context: GPUCanvasContext);
    cube3Phase: number;
    update(dt: number): void;
    render(now: number): void;
    startRendering(): void;
}
//# sourceMappingURL=sample.d.ts.map