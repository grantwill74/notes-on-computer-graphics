const terrainCode = /*wgsl*/ `

const MIN_HEIGHT: f32 = -3.0;
const MAX_HEIGHT: f32 = 3.0;
const WATER_LINE: f32 = 0.0;
const SAND_LINE_START: f32 = 0.25;
const SAND_LINE_END: f32 = 1.0;
const SNOW_LINE_START: f32 = 15.0;
const SNOW_LINE_END: f32 = 25.0;

@group(0) @binding(0) var<uniform> m_model: mat4x4<f32>;
@group(0) @binding(1) var<uniform> m_normal: mat3x3<f32>;

@group(1) @binding(0) var<uniform> m_view_proj: mat4x4<f32>;
@group(1) @binding(1) var<uniform> eye: vec3f;

@group(2) @binding(0) var samp: sampler;
@group(2) @binding(1) var tex_grass: texture_2d<f32>;
@group(2) @binding(2) var tex_sand: texture_2d<f32>;
@group(2) @binding(3) var tex_water: texture_2d<f32>;
@group(2) @binding(4) var tex_snow: texture_2d<f32>;
@group(2) @binding(5) var tex_stone: texture_2d<f32>;
/*
@group(2) @binding(5) var tex_dirt: texture_2d<f32>;
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
    // @location(2)    materials: vec4f,
) -> VertexOutput
{
    var vo: VertexOutput;
    vo.world_pos = m_model * vec4f(pos, 1.0);
    vo.pos = m_view_proj * vo.world_pos;
    vo.materials = vec4f(1.0, 0.0, 0.0, 0.0);
    vo.norm = normalize(m_normal * norm);

    return vo;
}

@fragment fn terrain_fs(vo: VertexOutput) -> @location(0) vec4f {
    const base_color = vec4f(0.0, 0.5, 0.0, 1.0);
    const min_color = vec4f(0.0, 0.1, 0.0, 1.0);
    const max_color = vec4f(0.0, 0.9, 0.0, 1.0);
    const min_bright = 0.1;
    const max_bright = 1.0;

    var color: vec4f;

    // Triplanar Mapping:
    // compute UVs to use for all 3 directions of sampling
    let uv_yz = vo.world_pos.yz; // perfect if normal is facing right/left
    let uv_xz = vo.world_pos.xz; // perfect if normal is facing up/down
    let uv_xy = vo.world_pos.xy; // perfect if normal is facing forward/back

    // which one is best? we can actually choose fractional amounts.
    // we will use the normal to tell us which direction the surface is pointing
    var weights = abs(normalize(vo.norm));

    // we can raise weights to a power to increase/decrease "sharpness". here, we 
    // want it to be reluctant to use the side texture (which is stone) unless
    // the surface is really steep
    weights.x = pow(weights.x, 4.0);
    weights.z = pow(weights.z, 4.0);

    // so weights.y is the amount that we want to sample uv_xz, which is perfect
    // when the normal is (0, 1, 0) (so if the normal is facing up, it uses only
    // that sample)

    // the denominator is the sum of weights. we're using a linear blend.
    let denom = weights.x + weights.y + weights.z;

    // notice that we actually sample stone for the vertical part of 
    // grass and snow.
    let samp_grass = 
        textureSample(tex_stone, samp, uv_yz) * weights.x / denom +
        textureSample(tex_grass, samp, uv_xz) * weights.y / denom +
        textureSample(tex_stone, samp, uv_xy) * weights.z / denom;
    
    let samp_sand = 
        textureSample(tex_sand, samp, uv_yz) * weights.x / denom +
        textureSample(tex_sand, samp, uv_xz) * weights.y / denom +
        textureSample(tex_sand, samp, uv_xy) * weights.z / denom;

    let samp_snow =
        textureSample(tex_stone, samp, uv_yz) * weights.x / denom +
        textureSample(tex_snow, samp, uv_xz) * weights.y / denom +
        textureSample(tex_stone, samp, uv_xy) * weights.z / denom;

    // the water is perfectly flat, so we don't need 
    let samp_water = textureSample(tex_water, samp, uv_xz);
    
    // don't need an epsilon comparison here. If you pick a non-exact, float,
    // like 0.1, you'll want one.
    if vo.world_pos.y == WATER_LINE {
        color = samp_water;
    }
    // haven't added transparency yet, so this doesn't show up.
    else if vo.world_pos.y < WATER_LINE {
        let bright = min_bright + (1.0 - vo.world_pos.y / MIN_HEIGHT) * max_bright;
        color = samp_sand * bright;
    }
    else if vo.world_pos.y < SAND_LINE_END {
        let alpha = (vo.world_pos.y - SAND_LINE_START) / (SAND_LINE_END - SAND_LINE_START);
        color = samp_sand * (1.0 - alpha) + samp_grass * alpha;
    }
    else if vo.world_pos.y >= SNOW_LINE_START {
        var alpha = (vo.world_pos.y - SNOW_LINE_START) / (SNOW_LINE_END - SNOW_LINE_START);
        alpha = clamp(alpha, 0.0, 1.0);
        color = mix(samp_grass, samp_snow, alpha * pow(alpha, 3.0));
        // mix is for linear blends. I'm raising alpha to a power to make it more gradual. 
    }
    else {
        color = samp_grass;
    }

    return color;
}
`;
const TAU = Math.PI * 2;
import { mat3, mat4, vec2, vec3 } from "gl-matrix";
const PERLIN_CHUNK_DIM = 32;
const PERLIN_FEATURE_DIM = 16;
const PERLIN_BASE_FREQ = 0.25;
// similar to AMD smoothstep from here: https://en.wikipedia.org/wiki/Smoothstep
function smoothstep(a, b, x) {
    const xi = (x - a) / (b - a);
    const xc = xi < 0 ? 0 : xi > 1 ? 1 : xi;
    return xc * xc * (3.0 - 2.0 * xc);
}
class HeightmapCache {
    rows;
    cols;
    topLeftRow;
    topLeftCol;
    heights;
    constructor(rows, cols, topLeftRow, topLeftCol, heights) {
        this.rows = rows;
        this.cols = cols;
        this.topLeftRow = topLeftRow;
        this.topLeftCol = topLeftCol;
        this.heights = heights;
    }
    sample(row, col) {
        const r = row - this.topLeftRow;
        const c = col - this.topLeftCol;
        const result = this.heights[r * this.cols + c];
        if (result === undefined)
            throw new Error(`Missing sample from cache: ${row}, ${col}`);
        return result;
    }
}
function heightmapSampleNormal(h, row, col) {
    const leftNeigh = [-1, h.sample(row, col - 1), 0];
    const rightNeigh = [1, h.sample(row, col + 1), 0];
    const tan = vec3.create();
    vec3.sub(tan, rightNeigh, leftNeigh);
    vec3.scale(tan, tan, 0.5);
    const upBit = [0, h.sample(row - 1, col), -1];
    const downBit = [0, h.sample(row + 1, col), 1];
    const bit = vec3.create();
    vec3.sub(bit, downBit, upBit);
    vec3.scale(bit, bit, 0.5);
    const normal = vec3.create();
    vec3.cross(normal, bit, tan);
    vec3.normalize(normal, normal);
    return normal;
}
export class ImageHeightmap {
    amp;
    samples;
    rows;
    cols;
    constructor(img, amp) {
        this.amp = amp;
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
                this.samples[row][col] = ((v / 255) - 0.5) * amp;
            }
        }
    }
    // assumes 0,0 is the center of the heightmap
    // not great software design to have an unused cache, but it was the easiest
    // way to speed things up and not refactor everything.
    sample(row, col) {
        if (this.rows == 0 || this.cols == 0)
            return 0;
        const topR = Math.max(Math.min(Math.floor(row), this.rows - 1), 0);
        const botR = Math.max(Math.min(Math.ceil(row), this.rows - 1), 0);
        const leftC = Math.max(Math.min(Math.floor(col), this.cols - 1), 0);
        const rightC = Math.max(Math.min(Math.ceil(col), this.cols - 1), 0);
        const tl = this.samples[topR][leftC];
        const tr = this.samples[topR][rightC];
        const bl = this.samples[botR][leftC];
        const br = this.samples[botR][rightC];
        const alphaHoriz = smoothstep(0, 1, col - leftC);
        const alphaVert = smoothstep(0, 1, row - topR);
        const sampHoriz1 = tl * (1 - alphaHoriz) + tr * alphaHoriz;
        const sampHoriz2 = bl * (1 - alphaHoriz) + br * alphaHoriz;
        const sampVert = sampHoriz1 * (1 - alphaVert) + sampHoriz2 * alphaVert;
        return sampVert;
    }
}
// hash function by cyrb53, released into the public domain
// https://github.com/bryc/code/blob/master/jshash/experimental/cyrb53.js 
const cyrb53 = function (str, seed = 0) {
    let h1 = 0xdeadbeef ^ seed, h2 = 0x41c6ce57 ^ seed;
    for (let i = 0, ch; i < str.length; i++) {
        ch = str.charCodeAt(i);
        h1 = Math.imul(h1 ^ ch, 2654435761);
        h2 = Math.imul(h2 ^ ch, 1597334677);
    }
    h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507);
    h1 ^= Math.imul(h2 ^ (h2 >>> 13), 3266489909);
    h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507);
    h2 ^= Math.imul(h1 ^ (h1 >>> 13), 3266489909);
    return 4294967296 * (2097151 & h2) + (h1 >>> 0);
};
// modification of the above for integers instead of strings
const cyrb53_int = function (i, seed = 0) {
    let h1 = 0xdeadbeef ^ seed, h2 = 0x41c6ce57 ^ seed;
    h1 = Math.imul(h1 ^ i, 2654435761);
    h2 = Math.imul(h2 ^ i, 1597334677);
    h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507);
    h1 ^= Math.imul(h2 ^ (h2 >>> 13), 3266489909);
    h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507);
    h2 ^= Math.imul(h1 ^ (h1 >>> 13), 3266489909);
    return 4294967296 * (2097151 & h2) + (h1 >>> 0);
};
// returns a value in the range [0, 1)
function hashPoint(seed, x, y) {
    const h0 = cyrb53(seed);
    const h1 = cyrb53_int(h0 ^ x);
    const h2 = cyrb53_int(h1 ^ y);
    // 24-bits is plenty. f32 range in case we want to do this on the GPU.
    return (h2 & 0xFFFFFF) / (0xFFFFFF + 1);
}
export class PerlinHeightmap {
    seed;
    nLevels;
    decay;
    baseAmp;
    constructor(seed, nLevels, decay, baseAmp) {
        this.seed = seed;
        this.nLevels = nLevels;
        this.decay = decay;
        this.baseAmp = baseAmp;
    }
    gradient(row, col) {
        const turns = hashPoint(this.seed, row, col);
        const rads = TAU * turns;
        const x = Math.cos(rads);
        const z = Math.sin(rads);
        return vec2.fromValues(x, z);
    }
    sampleLevel(row, col, level) {
        const freq = Math.pow(2, level) * PERLIN_BASE_FREQ;
        row = row * freq / PERLIN_FEATURE_DIM;
        col = col * freq / PERLIN_FEATURE_DIM;
        const top = Math.floor(row);
        const bot = top + 1;
        const left = Math.floor(col);
        const right = left + 1;
        const gtl = this.gradient(top, left);
        const gtr = this.gradient(top, right);
        const gbl = this.gradient(bot, left);
        const gbr = this.gradient(bot, right);
        const offtl = [row - top, col - left];
        const offtr = [row - top, col - right];
        const offbl = [row - bot, col - left];
        const offbr = [row - bot, col - right];
        // perlin requires smoothstep for conditioning the inputs so that the
        // change from one gradient vector to another is not abrupt.
        const u = smoothstep(0, 1, col - left); // u with the right derivative
        const topBlend = vec2.dot(offtl, gtl) * (1 - u) + vec2.dot(offtr, gtr) * u;
        const botBlend = vec2.dot(offbl, gbl) * (1 - u) + vec2.dot(offbr, gbr) * u;
        const v = smoothstep(0, 1, row - top);
        const finalBlend = topBlend * (1 - v) + botBlend * v;
        const amp = this.baseAmp * Math.pow(this.decay, level);
        let h = amp * finalBlend;
        return h;
    }
    sample(row, col) {
        let total = 0;
        for (let level = 0; level < this.nLevels; level++) {
            total += this.sampleLevel(row, col, level);
        }
        return total;
    }
}
/*
Vertex Format:
    position: vec3,
    normal: vec3,.
*/
const VERTEX_STRIDE = 3 * 4 + 3 * 4;
class HeightmapChunk {
    hm;
    topLeftRow;
    topLeftCol;
    rows;
    cols;
    vertData;
    indexData; // triangle strip
    constructor(hm, topLeftRow, topLeftCol, rows, cols) {
        this.hm = hm;
        this.topLeftRow = topLeftRow;
        this.topLeftCol = topLeftCol;
        this.rows = rows;
        this.cols = cols;
        const verts = [];
        const indis = [];
        const heights = new Array((rows + 3) * (cols + 3));
        for (let col = -1; col <= cols + 1; col++) {
            const worldRow = topLeftRow - 1;
            const worldCol = topLeftCol + col;
            const height = hm.sample(worldRow, worldCol);
            heights[col + 1] = height;
        }
        for (let row = 0; row <= rows + 1; row++) {
            for (let col = -1; col <= cols + 1; col++) {
                const worldRow = topLeftRow + row;
                const worldCol = topLeftCol + col;
                const height = hm.sample(worldRow, worldCol);
                heights[(row + 1) * (cols + 3) + col + 1] = height;
            }
        }
        const cache = new HeightmapCache(rows + 3, cols + 3, -1, -1, heights);
        for (let col = 0; col <= cols; col++) {
            const height = cache.sample(0, col);
            const normal = heightmapSampleNormal(cache, 0, col);
            verts.push(col, height, 0, ...normal);
        }
        for (let row = 1; row <= rows; row++) {
            for (let col = 0; col <= cols; col++) {
                const height = cache.sample(row, col);
                const normal = heightmapSampleNormal(cache, row, col);
                verts.push(col, height, row, ...normal);
                const i = row * (cols + 1) + col;
                indis.push(i - cols - 1, i);
            }
            indis.push(0xFFFFFFFF);
        }
        // put a water quad in the chunk
        // I hardcoded it to y = 0, which is fine but not ideal
        const i = (rows + 1) * (cols + 1);
        indis.push(i, i + 1, i + 2, i + 3);
        verts.push(0, 0, 0, 0, 1, 0);
        verts.push(0, 0, rows, 0, 1, 0);
        verts.push(cols, 0, 0, 0, 1, 0);
        verts.push(cols, 0, rows, 0, 1, 0);
        this.vertData = new Float32Array(verts);
        this.indexData = new Uint32Array(indis);
    }
    static idFromRowCol(tlRow, tlCol, rows, cols) {
        const row = tlRow / rows;
        const col = tlCol / cols;
        return HeightmapChunk.idFromChunkRowCol(row, col);
    }
    static idFromChunkRowCol(chunkRow, chunkCol) {
        return `${chunkRow.toString(16)},${chunkCol.toString(16)}`;
    }
    static chunkRowColFromId(id) {
        const [srow, scol] = id.split(',');
        const row = parseInt(srow, 16);
        const col = parseInt(scol, 16);
        if (isNaN(row) || isNaN(col)) {
            throw new Error("bad chunk ID: " + id);
        }
        return [row, col];
    }
    id() {
        return HeightmapChunk.idFromRowCol(this.topLeftRow, this.topLeftCol, this.rows, this.cols);
    }
}
class LoadedHeightmapMesh {
    verts;
    indis;
    nIndis;
    constructor(device, hm) {
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
    free() {
        this.verts.destroy();
        this.indis.destroy();
    }
}
class HeightmapNode {
    pos;
    chunk;
    static bgLayoutDesc = {
        entries: [
            {
                binding: 0,
                visibility: GPUShaderStage.VERTEX,
                buffer: {}
            },
            {
                binding: 1,
                visibility: GPUShaderStage.VERTEX,
                buffer: {}
            }
        ]
    };
    bg;
    modelBuf;
    normalBuf;
    mesh;
    constructor(device, pos, chunk) {
        this.pos = pos;
        this.chunk = chunk;
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
        (new Float32Array(this.normalBuf.getMappedRange())).set([
            n[0], n[1], n[2], 0,
            n[3], n[4], n[5], 0,
            n[6], n[7], n[8], 0
        ]);
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
    free() {
        this.mesh.free();
        this.modelBuf.destroy();
        this.normalBuf.destroy();
    }
}
const CAM_START = [0, 10, 0];
const CAM_ROT_SPEED = 1 / 4; // angular speed, turns per second
const CAM_MOVE_SPEED = 5; // scene units per second
const CAM_FAST_SPEED_MULT = 5; // multiplier for when shift is held
import { Keys } from '../sample09_nodes_and_cameras/sample.js';
export class Camera {
    yaw = 0;
    pitch = 0;
    pos = vec3.fromValues(0, 0, 0);
    scale = vec3.fromValues(1, 1, 1);
    model;
    view;
    viewBuf;
    name;
    constructor(name, device) {
        this.model = mat4.create();
        this.view = mat4.create();
        this.name = name;
        this.viewBuf = device.createBuffer({
            size: 16 * 4,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
            mappedAtCreation: false,
            label: name + " cam matrix",
        });
    }
    updateMatrix(device) {
        mat4.identity(this.model);
        mat4.translate(this.model, this.model, this.pos);
        mat4.rotateY(this.model, this.model, this.yaw * TAU);
        mat4.rotateX(this.model, this.model, this.pitch * TAU);
        mat4.scale(this.model, this.model, this.scale);
        mat4.invert(this.view, this.model);
        device.queue.writeBuffer(this.viewBuf, 0, new Float32Array(this.view));
    }
    // assumes matrix is up to date
    backward() {
        return vec3.fromValues(this.model[8], this.model[9], this.model[10]);
    }
    right() {
        return vec3.fromValues(this.model[0], this.model[1], this.model[2]);
    }
    up() {
        return vec3.fromValues(this.model[4], this.model[5], this.model[6]);
    }
}
const PERLIN_LEVELS = 5;
/// Keeps track of all the chunks around the current "center".
class RandomTerrain {
    heightmap;
    chunkDim;
    // we can't use tuples as nodes. We could try to pack our row,col coords 
    // into a single number, but it's easier to just turn them into strings.
    nodes = new Map();
    chunksLoaded = new Set();
    newChunkQueue = new Set();
    chunkRow = 0;
    chunkCol = 0;
    chunkDist;
    move(worldRowCoord, worldColCoord) {
        this.chunkRow = Math.floor(worldRowCoord / this.chunkDim);
        this.chunkCol = Math.floor(worldColCoord / this.chunkDim);
    }
    constructor(seed = "hi", decay = 0.5, amp = 1, viewDist = 128, chunkDim = PERLIN_CHUNK_DIM) {
        this.chunkDim = chunkDim;
        this.chunkDist = Math.ceil(viewDist / chunkDim);
        this.heightmap = new PerlinHeightmap(seed, PERLIN_LEVELS, decay, amp);
    }
    // construct a chunk if one is waiting
    tick(device) {
        if (this.newChunkQueue.size == 0)
            return;
        const id = this.newChunkQueue.keys().next().value;
        const [row, col] = HeightmapChunk.chunkRowColFromId(id);
        const tlRow = row * this.chunkDim;
        const tlCol = col * this.chunkDim;
        const chunk = new HeightmapChunk(this.heightmap, tlRow, tlCol, this.chunkDim, this.chunkDim);
        const node = new HeightmapNode(device, [tlCol, 0, tlRow], chunk);
        this.nodes.set(id, node);
        this.chunksLoaded.add(id);
        this.newChunkQueue.delete(id);
    }
    update(device) {
        const chunksNeeded = new Set();
        const left = Math.floor(this.chunkCol) - this.chunkDist;
        const right = Math.ceil(this.chunkCol) + this.chunkDist;
        const top = Math.floor(this.chunkRow) - this.chunkDist;
        const bot = Math.ceil(this.chunkRow) + this.chunkDist;
        for (let chunkRow = top; chunkRow <= bot; chunkRow++) {
            for (let chunkCol = left; chunkCol <= right; chunkCol++) {
                chunksNeeded.add(HeightmapChunk.idFromChunkRowCol(chunkRow, chunkCol));
            }
        }
        const chunksToFree = this.chunksLoaded.difference(chunksNeeded);
        for (let id of chunksToFree) {
            const node = this.nodes.get(id);
            if (!node)
                continue;
            node.free();
            this.nodes.delete(id);
        }
        this.chunksLoaded = this.chunksLoaded.difference(chunksToFree);
        const chunksMissing = chunksNeeded.difference(this.chunksLoaded);
        this.newChunkQueue = this.newChunkQueue.union(chunksMissing);
    }
}
export class Sample16 {
    device;
    context;
    grass;
    sand;
    water;
    snow;
    stone;
    // center: HeightmapNode;
    terrain;
    heightmapPipeline;
    viewBg;
    texBg;
    proj;
    mViewProjBuf;
    eyeBuf;
    cam;
    keys;
    canvasFormat;
    zBuffer;
    constructor(device, context, grass, sand, water, snow, stone) {
        //const imageHm = new ImageHeightmap(heightMap, 10);
        //const imageHm_chunk = new HeightmapChunk(
        //    imageHm, -imageHm.rows / 2, -imageHm.cols / 2, imageHm.rows, imageHm.cols);
        //this.center = new HeightmapNode(device,
        //    [-imageHm.cols / 2, 0, -imageHm.rows / 2], imageHm_chunk);
        this.device = device;
        this.context = context;
        this.grass = grass;
        this.sand = sand;
        this.water = water;
        this.snow = snow;
        this.stone = stone;
        /*
        const perlinNoise = new PerlinHeightmap("hey what's up", 9, 0.5, 4);
        const centerChunk = new HeightmapChunk(
            perlinNoise, 0, 0, PERLIN_CHUNK_DIM, PERLIN_CHUNK_DIM);
        this.center = new HeightmapNode(device,
            [-centerChunk.cols / 2, 0, -centerChunk.rows / 2], centerChunk);
        */
        this.terrain = new RandomTerrain("hi!", 0.35, 50, 500, PERLIN_CHUNK_DIM);
        this.terrain.move(0, 0);
        this.terrain.update(device);
        this.canvasFormat = (context.getCurrentTexture().format + '-srgb');
        const width = context.canvas.width;
        const height = context.canvas.height;
        this.zBuffer = device.createTexture({
            format: 'depth24plus-stencil8',
            size: { width, height, depthOrArrayLayers: 1 },
            usage: GPUTextureUsage.RENDER_ATTACHMENT,
        });
        const modelBgLayout = device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {},
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {},
                }
            ]
        });
        const viewBgLayout = device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {}
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {}
                }
            ]
        });
        const texBgLayout = device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: {}
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {}
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {}
                },
                {
                    binding: 3,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {}
                },
                {
                    binding: 4,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {}
                },
                {
                    binding: 5,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {}
                }
            ]
        });
        this.keys = new Keys();
        this.cam = new Camera('camera', device);
        vec3.add(this.cam.pos, this.cam.pos, CAM_START);
        this.cam.updateMatrix(device);
        this.mViewProjBuf = device.createBuffer({
            size: 16 * 4,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
            mappedAtCreation: true,
        });
        this.proj = mat4.create();
        mat4.perspectiveZO(this.proj, TAU / 6, width / height, 0.25, 1024);
        const viewProj = mat4.create();
        mat4.mul(viewProj, this.proj, this.cam.view);
        (new Float32Array(this.mViewProjBuf.getMappedRange())).set(viewProj);
        this.mViewProjBuf.unmap();
        this.eyeBuf = device.createBuffer({
            size: 4 * 4,
            usage: GPUBufferUsage.UNIFORM,
            mappedAtCreation: true,
        });
        (new Float32Array(this.eyeBuf.getMappedRange())).set([this.cam.model[12], this.cam.model[13], this.cam.model[14], 1]);
        this.eyeBuf.unmap();
        this.viewBg = device.createBindGroup({
            layout: viewBgLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.mViewProjBuf,
                },
                {
                    binding: 1,
                    resource: this.eyeBuf
                }
            ]
        });
        const sampler = device.createSampler({
            addressModeU: 'repeat',
            addressModeV: 'repeat',
            minFilter: 'linear',
            magFilter: 'linear',
            mipmapFilter: 'linear',
            maxAnisotropy: 16,
        });
        this.texBg = device.createBindGroup({
            layout: texBgLayout,
            entries: [
                {
                    binding: 0,
                    resource: sampler,
                },
                {
                    binding: 1,
                    resource: grass.createView()
                },
                {
                    binding: 2,
                    resource: sand.createView()
                },
                {
                    binding: 3,
                    resource: water.createView()
                },
                {
                    binding: 4,
                    resource: snow.createView()
                },
                {
                    binding: 5,
                    resource: stone.createView()
                }
            ]
        });
        const hmPipelineLayout = device.createPipelineLayout({
            bindGroupLayouts: [
                modelBgLayout,
                viewBgLayout,
                texBgLayout,
            ],
        });
        const shaderMod = device.createShaderModule({ code: terrainCode });
        this.heightmapPipeline = device.createRenderPipeline({
            layout: hmPipelineLayout,
            vertex: {
                module: shaderMod,
                buffers: [
                    {
                        arrayStride: VERTEX_STRIDE,
                        attributes: [
                            {
                                format: 'float32x3',
                                offset: 0,
                                shaderLocation: 0,
                            },
                            {
                                format: 'float32x3',
                                offset: 3 * 4,
                                shaderLocation: 1,
                            }
                        ]
                    }
                ]
            },
            fragment: {
                module: shaderMod,
                targets: [
                    {
                        format: this.canvasFormat,
                    }
                ]
            },
            primitive: {
                cullMode: 'none', // for now
                frontFace: 'ccw',
                topology: 'triangle-strip',
                stripIndexFormat: 'uint32',
            },
            depthStencil: {
                format: 'depth24plus-stencil8',
                depthWriteEnabled: true,
                depthCompare: 'less-equal',
            }
        });
    }
    startRendering() {
        const renderAndRequeue = (now) => {
            this.render(now);
            requestAnimationFrame(renderAndRequeue);
        };
        renderAndRequeue(performance.now());
    }
    update(_now, dtime) {
        const k = this.keys;
        const c = this.cam;
        const moveAmnt = CAM_MOVE_SPEED * dtime *
            (k.isDown('ShiftLeft') ? CAM_FAST_SPEED_MULT : 1);
        const rotAmnt = CAM_ROT_SPEED * dtime;
        if (k.isDown('KeyW')) {
            vec3.scaleAndAdd(c.pos, c.pos, c.backward(), -moveAmnt);
        }
        if (k.isDown('KeyS')) {
            vec3.scaleAndAdd(c.pos, c.pos, c.backward(), moveAmnt);
        }
        if (k.isDown('KeyA')) {
            vec3.scaleAndAdd(c.pos, c.pos, c.right(), -moveAmnt);
        }
        if (k.isDown('KeyD')) {
            vec3.scaleAndAdd(c.pos, c.pos, c.right(), moveAmnt);
        }
        if (k.isDown('Space')) {
            vec3.scaleAndAdd(c.pos, c.pos, c.up(), moveAmnt);
        }
        if (k.isDown('KeyC')) {
            vec3.scaleAndAdd(c.pos, c.pos, c.up(), -moveAmnt);
        }
        if (k.isDown('ArrowLeft')) {
            c.yaw += rotAmnt;
        }
        if (k.isDown('ArrowRight')) {
            c.yaw -= rotAmnt;
        }
        if (k.isDown('ArrowDown')) {
            c.pitch += rotAmnt;
        }
        if (k.isDown('ArrowUp')) {
            c.pitch -= rotAmnt;
        }
        c.updateMatrix(this.device);
        const camRow = this.cam.pos[2];
        const camCol = this.cam.pos[0];
        const camRowChunk = Math.floor(camRow / this.terrain.chunkDim);
        const camColChunk = Math.floor(camCol / this.terrain.chunkDim);
        if (camRowChunk != this.terrain.chunkRow || camColChunk != this.terrain.chunkCol)
            this.terrain.update(this.device);
        this.terrain.tick(this.device);
        this.terrain.move(camRow, camCol);
        const viewProj = mat4.create();
        mat4.mul(viewProj, this.proj, this.cam.view);
        this.device.queue.writeBuffer(this.mViewProjBuf, 0, new Float32Array(viewProj));
    }
    lastUpdate = performance.now();
    render(now) {
        const dtime = (now - this.lastUpdate) / 1000;
        this.lastUpdate = now;
        this.update(now / 1000, dtime);
        const enc = this.device.createCommandEncoder();
        const ctx = this.context;
        const canv = ctx.canvas;
        const pass = enc.beginRenderPass({
            colorAttachments: [
                {
                    loadOp: 'clear',
                    storeOp: 'store',
                    clearValue: { r: .7, g: .8, b: .9, a: 1 },
                    view: ctx.getCurrentTexture().createView({
                        format: this.canvasFormat,
                    }),
                }
            ],
            depthStencilAttachment: {
                view: this.zBuffer.createView(),
                depthClearValue: 1,
                depthLoadOp: 'clear',
                depthStoreOp: 'store',
                stencilReadOnly: true,
            }
        });
        pass.setViewport(0, 0, canv.width, canv.height, 0, 1);
        pass.setPipeline(this.heightmapPipeline);
        pass.setBindGroup(1, this.viewBg);
        pass.setBindGroup(2, this.texBg);
        for (let [_, node] of this.terrain.nodes) {
            pass.setBindGroup(0, node.bg);
            pass.setVertexBuffer(0, node.mesh.verts);
            pass.setIndexBuffer(node.mesh.indis, 'uint32');
            pass.drawIndexed(node.mesh.nIndis);
        }
        pass.end();
        const commands = enc.finish();
        this.device.queue.submit([commands]);
    }
}
//# sourceMappingURL=sample.js.map