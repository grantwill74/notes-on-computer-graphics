import { vec3 } from 'gl-matrix';
import { SimpleNode } from '../sample09_nodes_and_cameras/sample.js';
export declare class SimpleMesh {
    indices: number[];
    positions: vec3[];
    colors: vec3[];
    nVerts: number;
    topology: GPUPrimitiveTopology;
    stride: number;
    name: string;
    constructor(topo: GPUPrimitiveTopology, indices: number[], positions: vec3[], colors: vec3[], name?: string);
}
declare class LoadedSimpleMesh {
    vertexBuffer: GPUBuffer;
    indexBuffer: GPUBuffer;
    nVerts: number;
    nIndis: number;
    topology: GPUPrimitiveTopology;
    constructor(device: GPUDevice, data: SimpleMesh);
}
export declare function loadObj(url: URL): Promise<SimpleMesh>;
export declare class Sample10 {
    device: GPUDevice;
    context: GPUCanvasContext;
    mesh: LoadedSimpleMesh;
    teapot: SimpleNode;
    camera: SimpleNode;
    matViewProj: GPUBuffer;
    bgViewProj: GPUBindGroup;
    pipeline: GPURenderPipeline;
    zBuffer: GPUTexture;
    format: GPUTextureFormat;
    lastUpdate: number;
    constructor(device: GPUDevice, context: GPUCanvasContext, meshData: SimpleMesh);
    startRendering(): void;
    render(now: number): void;
}
export {};
//# sourceMappingURL=sample.d.ts.map