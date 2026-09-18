import { mat4, vec3 } from "gl-matrix";
interface Heightmap {
    sample(row: number, col: number): number;
}
export declare class ImageHeightmap implements Heightmap {
    amp: number;
    samples: number[][];
    rows: number;
    cols: number;
    constructor(img: ImageData, amp: number);
    sample(row: number, col: number): number;
}
export declare class PerlinHeightmap implements Heightmap {
    seed: string;
    nLevels: number;
    decay: number;
    baseAmp: number;
    constructor(seed: string, nLevels: number, decay: number, baseAmp: number);
    private gradient;
    private sampleLevel;
    sample(row: number, col: number): number;
}
declare class HeightmapChunk {
    hm: Heightmap;
    topLeftRow: number;
    topLeftCol: number;
    rows: number;
    cols: number;
    vertData: Float32Array;
    indexData: Uint32Array;
    constructor(hm: Heightmap, topLeftRow: number, topLeftCol: number, rows: number, cols: number);
    static idFromRowCol(tlRow: number, tlCol: number, rows: number, cols: number): string;
    static idFromChunkRowCol(chunkRow: number, chunkCol: number): string;
    static chunkRowColFromId(id: string): [number, number];
    id(): string;
}
declare class LoadedHeightmapMesh {
    verts: GPUBuffer;
    indis: GPUBuffer;
    nIndis: number;
    constructor(device: GPUDevice, hm: HeightmapChunk);
    free(): void;
}
declare class HeightmapNode {
    pos: vec3;
    chunk: HeightmapChunk;
    static bgLayoutDesc: GPUBindGroupLayoutDescriptor;
    bg: GPUBindGroup;
    modelBuf: GPUBuffer;
    normalBuf: GPUBuffer;
    mesh: LoadedHeightmapMesh;
    constructor(device: GPUDevice, pos: vec3, chunk: HeightmapChunk);
    free(): void;
}
import { Keys } from '../sample09_nodes_and_cameras/sample.js';
export declare class Camera {
    yaw: number;
    pitch: number;
    pos: vec3;
    scale: vec3;
    model: mat4;
    view: mat4;
    viewBuf: GPUBuffer;
    name: string;
    constructor(name: string, device: GPUDevice);
    updateMatrix(device: GPUDevice): void;
    backward(): vec3;
    right(): vec3;
    up(): vec3;
}
declare class RandomTerrain {
    heightmap: PerlinHeightmap;
    chunkDim: number;
    nodes: Map<string, HeightmapNode>;
    chunksLoaded: Set<string>;
    newChunkQueue: Set<string>;
    chunkRow: number;
    chunkCol: number;
    chunkDist: number;
    move(worldRowCoord: number, worldColCoord: number): void;
    constructor(seed?: string, decay?: number, amp?: number, viewDist?: number, chunkDim?: number);
    tick(device: GPUDevice): void;
    update(device: GPUDevice): void;
}
export declare class Sample16 {
    device: GPUDevice;
    context: GPUCanvasContext;
    grass: GPUTexture;
    sand: GPUTexture;
    water: GPUTexture;
    snow: GPUTexture;
    stone: GPUTexture;
    terrain: RandomTerrain;
    heightmapPipeline: GPURenderPipeline;
    viewBg: GPUBindGroup;
    texBg: GPUBindGroup;
    proj: mat4;
    mViewProjBuf: GPUBuffer;
    eyeBuf: GPUBuffer;
    cam: Camera;
    keys: Keys;
    canvasFormat: GPUTextureFormat;
    zBuffer: GPUTexture;
    constructor(device: GPUDevice, context: GPUCanvasContext, grass: GPUTexture, sand: GPUTexture, water: GPUTexture, snow: GPUTexture, stone: GPUTexture);
    startRendering(): void;
    update(_now: number, dtime: number): void;
    lastUpdate: number;
    render(now: number): void;
}
export {};
//# sourceMappingURL=sample.d.ts.map