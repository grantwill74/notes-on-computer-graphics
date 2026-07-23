import { vec3, mat4 } from 'gl-matrix';
export declare class PositionMesh {
    indices: number[];
    positions: vec3[];
    nVerts: number;
    topology: GPUPrimitiveTopology;
    stride: number;
    name: string;
    constructor(topo: GPUPrimitiveTopology, indices: number[], positions: vec3[], name?: string);
}
declare class LoadedPositionMesh {
    vertexBuffer: GPUBuffer;
    indexBuffer: GPUBuffer;
    nVerts: number;
    nIndis: number;
    topology: GPUPrimitiveTopology;
    constructor(device: GPUDevice, data: PositionMesh);
}
export declare class SceneNode {
    finalMatrix: mat4;
    children: SceneNode[];
    parent: SceneNode | undefined;
    color: vec3;
    localMatrix: mat4;
    finalBuf: GPUBuffer;
    colorBuf: GPUBuffer;
    modelBg: GPUBindGroup;
    mesh: LoadedPositionMesh | undefined;
    name: string | undefined;
    constructor(device: GPUDevice, modelColorLayout: GPUBindGroupLayout, name?: string);
    updateData(device: GPUDevice): void;
    move(pos: vec3): void;
    rotateX(amount: number): void;
    rotateY(amount: number): void;
    rotateZ(amount: number): void;
    scale(amount: vec3): void;
    addChild(device: GPUDevice, layout: GPUBindGroupLayout, name?: string): SceneNode;
}
export declare class Sample11 {
    device: GPUDevice;
    context: GPUCanvasContext;
    cube: LoadedPositionMesh;
    projBuf: GPUBuffer;
    projBg: GPUBindGroup;
    pipeline: GPURenderPipeline;
    zBuffer: GPUTexture;
    format: GPUTextureFormat;
    root: SceneNode;
    lastUpdate: number;
    constructor(device: GPUDevice, context: GPUCanvasContext);
    startRendering(): void;
    update(t: number, dt: number): void;
    render(now: number): void;
}
export {};
//# sourceMappingURL=sample.d.ts.map