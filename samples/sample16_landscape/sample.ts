const terrainCode = /*wgsl*/`

const MIN_HEIGHT: f32 = -10.0;
const MAX_HEIGHT: f32 = 100.0;
const WATER_LINE: f32 = 0.0;

@group(0) @binding(0) var<uniform> m_model: mat4x4<f32>;
@group(0) @binding(1) var<uniform> m_normal: mat3x3<f32>;

@group(1) @binding(0) var<uniform> m_view: mat4x4<f32>;
@group(1) @binding(1) var<uniform> m_proj: mat4x4<f32>;
@group(1) @binding(2) var<uniform> eye: vec3f;

/*
@group(2) @binding(0) var samp: sampler;
@group(2) @binding(1) var tex_grass: texture_2d<f32>;
@group(2) @binding(2) var tex_dirt: texture_2d<f32>;
@group(2) @binding(3) var tex_sand: texture_2d<f32>;
@group(2) @binding(4) var tex_stone: texture_2d<f32>;
@group(2) @binding(5) var tex_snow: texture_2d<f32>;
*/

struct VertexOutput {
    @builtin(position)  pos: vec4f,
    @location(0)        norm: vec3f,
    @location(1)        materials: vec4f,
    // UVs will come from position, which is in world units    
    @location(2)        world_pos: vec4f,
}

@vertex fn terrain_vs(
    @location(0)    pos: vec3f,
    @location(1)    norm: vec3f,
    @location(2)    materials: vec4f,
) -> VertexOutput
{
    var vo: VertexOutput;
    vo.world_pos = m_model * vec4f(pos, 1.0);
    vo.pos = m_proj * m_view * vo.world_pos;
    vo.materials = materials;
    vo.norm = normalize(m_normal * norm);

    return vo;
}

@fragment fn terrain_fs(vo: VertexOutput) -> @location(0) vec4f {
    const base_color = vec4f(0.0, 0.5, 0.0, 1.0);
    const min_color = vec4f(0.0, 0.1, 0.0, 1.0);
    const max_color = vec4f(0.0, 0.9, 0.0, 1.0);

    var color: vec4f;

    if vo.pos.y < WATER_LINE {
        let weight = vo.pos.y / MIN_HEIGHT;
        color = min_color * weight + base_color * (1 - weight);
    }
    else {
        let weight = vo.pos.y / MAX_HEIGHT;
        color = max_color * weight + base_color * (1 - weight);
    }

    return color;
}
`;

import { mat3, mat4, vec3 } from "gl-matrix";

const PERLIN_CHUNK_DIM = 64;
const PERLIN_LATTICE_DIM = 17;

// similar to AMD smoothstep from here: https://en.wikipedia.org/wiki/Smoothstep
function smoothstep(a: number, b: number, x: number): number {
    const xi = (x - a) / (b - a);
    const xc = xi < 0 ? 0 : xi > 1 ? 1 : xi;
    return xc * xc * (3.0 - 2.0 * xc);
}

interface Heightmap {
    sample(row: number, col: number): number; 
}

function heightmapSampleNormal(h: Heightmap, row: number, col: number): vec3 {
    const leftNeigh: vec3 = [-1, h.sample(col - 1, row), 0];
    const rightNeigh: vec3 = [1, h.sample(col + 1, row), 0];
    const tan = vec3.create();
    
    vec3.sub(tan, rightNeigh, leftNeigh);
    vec3.scale(tan, tan, 0.5);

    const upBit: vec3 = [0, h.sample(col, row - 1), -1];
    const downBit: vec3 = [0, h.sample(col, row + 1), 1];
    const bit = vec3.create();

    vec3.sub(bit, downBit, upBit);
    vec3.scale(bit, bit, 0.5);

    const normal = vec3.create();
    vec3.cross(normal, bit, tan);

    vec3.normalize(normal, normal);

    return normal;
}

export class ImageHeightmap implements Heightmap {
    samples: number[][];
    rows: number;
    cols: number;
    
    constructor(
        img: ImageData,
        public amp: number
    ) {
        this.rows = img.height;
        this.cols = img.width;
        this.samples = new Array(this.rows); 
        
        for (let row = 0; row < img.height; row++) {
            this.samples[row] = new Array(this.cols);
            for (let col = 0; col < img.width; col++) {
                let i = row * img.width + col;
                let p = i * 4;
                let v = img.data.at(p);
                if (v === undefined)
                    throw new Error("Image data does not agree with dims.");

                this.samples[row]![col] = ((v / 255) - 0.5) * amp;
            }
        }
    }

    /// returns [row_offset, col_offset]
    get centerOff(): [number, number] {
        return [
            this.rows / 2,
            this.cols / 2,
        ];
    }

    // assumes 0,0 is the center of the heightmap
    sample(row: number, col: number): number {
        if (this.rows == 0 || this.cols == 0) return 0;

        const [rowOff, colOff] = this.centerOff;

        const r = row + rowOff;
        const c = col + colOff;

        const topR = Math.max(Math.min(Math.floor(r), this.rows - 1), 0);
        const botR = Math.max(Math.min(Math.ceil(r), this.rows - 1), 0);
        const leftC = Math.max(Math.min(Math.floor(c), this.cols - 1), 0);
        const rightC = Math.max(Math.min(Math.ceil(c), this.cols - 1), 0);

        const tl = this.samples[topR]![leftC]!;
        const tr = this.samples[topR]![rightC]!;
        const bl = this.samples[botR]![leftC]!;
        const br = this.samples[botR]![rightC]!;

        const alphaHoriz = smoothstep(0, 1, c - leftC);
        const alphaVert = smoothstep(0, 1, r - topR);

        const sampHoriz1 = tl * (1 - alphaHoriz) + tr * alphaHoriz;
        const sampHoriz2 = bl * (1 - alphaHoriz) + br * alphaHoriz;
        const sampVert = sampHoriz1 * (1 - alphaVert) + sampHoriz2 * alphaVert;

        return sampVert;
    }
}

/*
Vertex Format:
    position: vec3,
    normal: vec3,.
*/

class HeightmapChunk {
    vertData: Float32Array;
    indexData: Uint32Array; // triangle strip

    constructor(
        public hm: Heightmap,
        public rows: number,
        public cols: number,
    ) {
        const verts = [];
        const indis = [];
        let i = 0;

        for (let row = 0; row < rows; row++) {
            for (let col = 0; col < cols; col++) {
                const height = hm.sample(row, col);
                const normal = heightmapSampleNormal(hm, row, col);
                verts.push(col, height, row, ...normal);

                indis.push(i, i + 1);
                i += 2;
            }

            indis.push(0xFFFFFFFF);
        }

        this.vertData = new Float32Array(verts);
        this.indexData = new Uint32Array(indis);
    }
}

class LoadedHeightmapMesh {
    verts: GPUBuffer;
    indis: GPUBuffer;
    nIndis: number;

    constructor(device: GPUDevice, hm: HeightmapChunk) {
        this.verts = device.createBuffer({
            size: hm.vertData.byteLength,
            usage: GPUBufferUsage.VERTEX,
            mappedAtCreation: true,
        });
        (new Float32Array(this.verts.getMappedRange())).set(hm.vertData);
        this.verts.unmap();

        this.indis = device.createBuffer({
            size: hm.indexData.byteLength,
            usage: GPUBufferUsage.INDEX,
            mappedAtCreation: true,
        });
        (new Uint32Array(this.indis.getMappedRange())).set(hm.indexData);
        this.indis.unmap();

        this.nIndis = hm.indexData.length;
    }
}

class HeightmapNode {
    static bgLayoutDesc: GPUBindGroupLayoutDescriptor = {
        entries: [
            { // model
                binding: 0,
                visibility: GPUShaderStage.VERTEX,
                buffer: {}
            },
            { // normal
                binding: 1,
                visibility: GPUShaderStage.VERTEX,
                buffer: {}
            }
        ]
    };
    bg: GPUBindGroup;

    modelBuf: GPUBuffer;
    normalBuf: GPUBuffer;
    mesh: LoadedHeightmapMesh;

    constructor(
        device: GPUDevice,
        public pos: vec3,
        public chunk: HeightmapChunk,
    ) {
        this.mesh = new LoadedHeightmapMesh(device, chunk);

        const model = mat4.create();
        mat4.translate(model, model, pos);

        const normal = mat3.create();
        mat3.normalFromMat4(normal, model); // will just be cut off mat4

        this.modelBuf = device.createBuffer({
            size: 16 * 4,
            usage: GPUBufferUsage.UNIFORM,
            mappedAtCreation: true,
        });
        (new Float32Array(this.modelBuf.getMappedRange())).set(model);
        this.modelBuf.unmap();

        this.normalBuf = device.createBuffer({
            size: 12 * 4,
            usage: GPUBufferUsage.UNIFORM,
            mappedAtCreation: true
        });
        const n = normal;
        (new Float32Array(this.modelBuf.getMappedRange())).set(
            [
                n[0], n[1], n[2], 0,
                n[3], n[4], n[5], 0,
                n[6], n[7], n[8], 0
            ]
        );
        this.normalBuf.unmap();

        this.bg = device.createBindGroup({
            layout: device.createBindGroupLayout(HeightmapNode.bgLayoutDesc),
            entries: [
                {
                    binding: 0,
                    resource: this.modelBuf
                },
                {
                    binding: 1,
                    resource: this.normalBuf
                }
            ]
        });
    }
}

export class Sample16 {
    center: HeightmapNode;
    heightmapPipeline: GPURenderPipeline;


    constructor(
        public device: GPUDevice,
        public context: GPUCanvasContext,
        heightMap: ImageData,
    ) {
        const imageHm = new ImageHeightmap(heightMap, 5);
        const imageHm_chunk = new HeightmapChunk(imageHm, imageHm.rows, imageHm.cols);
        this.center = new HeightmapNode(device, [0, 0, 0], imageHm_chunk);

        const hmPipelineLayout = device.createPipelineLayout({
            
        });
    }
}
