import { mat4 } from 'gl-matrix';
export declare class Mesh {
    vertData: number[];
    indices: number[];
    constructor(vertData: number[], indices: number[]);
}
export declare function genUvSphere(xzSubdivs: number, ySubdivs: number, topo: GPUPrimitiveTopology): Mesh;
export declare function genCubeSphere(nFaceSubdivs: number, topo: GPUPrimitiveTopology): Mesh;
export declare function loadCubemapUnfurled(device: GPUDevice, url: URL, uvs: [number, number][], faceDim: [number, number]): Promise<GPUTexture>;
export declare function genCubeMesh(): Mesh;
export declare function loadCubemap6Images(device: GPUDevice, dim: number, url: URL[], flips: number[]): Promise<GPUTexture>;
export declare class LoadedMesh {
    verts: GPUBuffer;
    indis: GPUBuffer;
    nIndis: number;
    constructor(device: GPUDevice, mesh: Mesh);
}
export declare class Sample14 {
    device: GPUDevice;
    context: GPUCanvasContext;
    uvSphere: LoadedMesh;
    cubeSphere: LoadedMesh;
    skyCube: LoadedMesh;
    sphereMapPipeline: GPURenderPipeline;
    cubeMapPipeline: GPURenderPipeline;
    skyPipeline: GPURenderPipeline;
    format: GPUTextureFormat;
    passBg: GPUBindGroup;
    sphereModelBg: GPUBindGroup;
    cubeModelBg: GPUBindGroup;
    skyModelBg: GPUBindGroup;
    sphereModelMatBuf: GPUBuffer;
    cubeModelMatBuf: GPUBuffer;
    skyModelMatBuf: GPUBuffer;
    projBuf: GPUBuffer;
    projMat: mat4;
    sphereSampler: GPUSampler;
    cubeSampler: GPUSampler;
    constructor(device: GPUDevice, context: GPUCanvasContext, sphereMap: GPUTexture, cubeMap: GPUTexture, skyBox: GPUTexture);
    sphereTurns: number;
    skyTurns: number;
    update(dt: number): void;
    lastRender: number;
    render(now: number): void;
    startRendering(): void;
}
//# sourceMappingURL=sample.d.ts.map