import { mat4 } from 'gl-matrix';
declare class Mesh {
    vertData: number[];
    indices: number[];
    constructor(vertData: number[], indices: number[]);
}
export declare function genUvSphere(xzSubdivs: number, ySubdivs: number, topo: GPUPrimitiveTopology): Mesh;
export declare function genCubeSphere(nFaceSubdivs: number, topo: GPUPrimitiveTopology): Mesh;
export declare function loadCubemapUnfurled(device: GPUDevice, url: URL, uvs: [number, number][], faceDim: [number, number]): Promise<GPUTexture>;
declare class LoadedMesh {
    verts: GPUBuffer;
    indis: GPUBuffer;
    nIndis: number;
    constructor(device: GPUDevice, mesh: Mesh);
}
export declare class Sample14 {
    device: GPUDevice;
    context: GPUCanvasContext;
    sphereMap: GPUTexture;
    cubeMap: GPUTexture;
    uvSphere: LoadedMesh;
    cubeSphere: LoadedMesh;
    sphereMapPipeline: GPURenderPipeline;
    cubeMapPipeline: GPURenderPipeline;
    format: GPUTextureFormat;
    passBg: GPUBindGroup;
    sphereModelBg: GPUBindGroup;
    cubeModelBg: GPUBindGroup;
    sphereModelMatBuf: GPUBuffer;
    projBuf: GPUBuffer;
    projMat: mat4;
    sphereModelMat: mat4;
    sphereSampler: GPUSampler;
    cubeSampler: GPUSampler;
    constructor(device: GPUDevice, context: GPUCanvasContext, sphereMap: GPUTexture, cubeMap: GPUTexture);
    sphereTurns: number;
    update(dt: number): void;
    lastRender: number;
    render(now: number): void;
    startRendering(): void;
}
export {};
//# sourceMappingURL=sample.d.ts.map