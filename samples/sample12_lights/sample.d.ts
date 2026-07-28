import { vec3, mat4, mat3 } from "gl-matrix";
export declare class Mesh {
    indices: number[];
    vertData: number[];
    nVerts: number;
    stride: number;
    name: string;
    minX: number;
    maxX: number;
    minY: number;
    maxY: number;
    minZ: number;
    maxZ: number;
    xDist: number;
    yDist: number;
    zDist: number;
    widestExtent: number;
    offset: vec3;
    constructor(indices: number[], positions: vec3[], name?: string);
}
export declare function loadObj(url: URL): Promise<Mesh>;
export declare function simpleCubeMesh(): Mesh;
export declare class LoadedMesh {
    vertexBuffer: GPUBuffer;
    indexBuffer: GPUBuffer;
    nVerts: number;
    nIndis: number;
    constructor(device: GPUDevice, data: Mesh);
}
export declare class Sample12 {
    device: GPUDevice;
    context: GPUCanvasContext;
    meshes: Map<string, Mesh>;
    loaded: Map<string, LoadedMesh>;
    currentMesh: string;
    matProj: mat4;
    matModel: mat4;
    matNormal: mat3;
    mtlAmbient: vec3;
    mtlDiffuse: vec3;
    ambientColor: vec3;
    dirLightDir: vec3;
    dirLightColor: vec3;
    matProjBuf: GPUBuffer;
    matModelBuf: GPUBuffer;
    matNormalBuf: GPUBuffer;
    mtlAmbientBuf: GPUBuffer;
    mtlDiffuseBuf: GPUBuffer;
    ambientColorBuf: GPUBuffer;
    dirLightDirBuf: GPUBuffer;
    dirLightColorBuf: GPUBuffer;
    format: GPUTextureFormat;
    bgProj: GPUBindGroup;
    bgLight: GPUBindGroup;
    bgModel: GPUBindGroup;
    pipeline: GPURenderPipeline;
    zBuffer: GPUTexture;
    lastUpdate: number;
    constructor(device: GPUDevice, context: GPUCanvasContext, meshes: Map<string, Mesh>);
    changeCurrentMesh(change: string): void;
    changeDirLightColor(change: vec3): void;
    changeAmbientColor(change: vec3): void;
    changeMaterialAmbient(change: vec3): void;
    changeMaterialDiffuse(change: vec3): void;
    update(t: number, dt: number): void;
    render(now: number): void;
    startRendering(): void;
}
//# sourceMappingURL=sample.d.ts.map