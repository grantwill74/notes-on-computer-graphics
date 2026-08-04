declare class Mesh {
    vertData: number[];
    indices: number[];
    constructor(vertData: number[], indices: number[]);
}
export declare function genUvSphere(xzSubdivs: number, ySubdivs: number, topo: GPUPrimitiveTopology): Mesh;
export declare function genCubeSphere(): number[];
declare class LoadedMesh {
    verts: GPUBuffer;
    indis: GPUBuffer;
    nVerts: number;
    nIndis: number;
    constructor(device: GPUDevice, mesh: Mesh);
}
import { mat4 } from 'gl-matrix';
export declare class Sample14 {
    device: GPUDevice;
    context: GPUCanvasContext;
    sphereMap: GPUTexture;
    uvSphere: LoadedMesh;
    sphereMapPipeline: GPURenderPipeline;
    format: GPUTextureFormat;
    passBgLayout: GPUBindGroupLayout;
    modelBgLayout: GPUBindGroupLayout;
    passBg: GPUBindGroup;
    sphereModelBg: GPUBindGroup;
    sphereModelMatBuf: GPUBuffer;
    projBuf: GPUBuffer;
    projMat: mat4;
    sphereModelMat: mat4;
    sphereSampler: GPUSampler;
    constructor(device: GPUDevice, context: GPUCanvasContext, sphereMap: GPUTexture);
    update(): void;
    render(): void;
}
export {};
//# sourceMappingURL=sample.d.ts.map