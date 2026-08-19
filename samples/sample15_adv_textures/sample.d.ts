import { vec3, mat4 } from 'gl-matrix';
export declare function genCheckerboardTex(device: GPUDevice, tileDim: number, nMipLevels: number): Promise<GPUTexture>;
export declare function createMipmapPipeline(device: GPUDevice): GPURenderPipeline;
export declare function genMips(device: GPUDevice, tex: GPUTexture, nLayers: number, pipeline: GPURenderPipeline): void;
export declare class Sample15 {
    device: GPUDevice;
    context: GPUCanvasContext;
    texChecker: GPUTexture;
    texCheckerMip: GPUTexture;
    mModel: mat4;
    mView: mat4;
    mProj: mat4;
    texDepth: GPUTexture;
    bufVerts: GPUBuffer;
    bufMatrices: GPUBuffer;
    mCam: mat4;
    camPos: vec3;
    camPitch: number;
    camYaw: number;
    camRoll: number;
    camPitchAmnt: number;
    camYawAmnt: number;
    camRollAmnt: number;
    camMoveAmnt: vec3;
    pipeline: GPURenderPipeline;
    bgMatrices: GPUBindGroup;
    bgTexes: GPUBindGroup;
    constructor(device: GPUDevice, context: GPUCanvasContext, texChecker: GPUTexture, texCheckerMip: GPUTexture);
    camAddAngles(yaw: number, pitch: number, roll: number): void;
    update(): void;
    forward(): vec3;
    up(): vec3;
    right(): vec3;
    startUpdating(): void;
    render(): void;
    startRendering(): void;
}
//# sourceMappingURL=sample.d.ts.map