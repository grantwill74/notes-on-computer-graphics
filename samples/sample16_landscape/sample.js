const terrainCode = /*wgsl*/ `

const MIN_HEIGHT: f32 = -3.0;
const MAX_HEIGHT: f32 = 3.0;
const WATER_LINE: f32 = 0.0;

@group(0) @binding(0) var<uniform> m_model: mat4x4<f32>;
@group(0) @binding(1) var<uniform> m_normal: mat3x3<f32>;

@group(1) @binding(0) var<uniform> m_view_proj: mat4x4<f32>;
@group(1) @binding(1) var<uniform> eye: vec3f;

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

    var color: vec4f;

    if vo.world_pos.y < WATER_LINE {
        let weight = vo.world_pos.y / MIN_HEIGHT;
        color = min_color * weight + base_color * (1 - weight);
        color = vec4f(color.r, color.bg, color.a);
    }
    else {
        let weight = vo.world_pos.y / MAX_HEIGHT;
        color = max_color * weight + base_color * (1 - weight);
    }

    return color;
}
`;
const TAU = Math.PI * 2;
import { mat3, mat4, vec3 } from "gl-matrix";
const PERLIN_CHUNK_DIM = 64;
const PERLIN_LATTICE_DIM = 17;
// similar to AMD smoothstep from here: https://en.wikipedia.org/wiki/Smoothstep
function smoothstep(a, b, x) {
    const xi = (x - a) / (b - a);
    const xc = xi < 0 ? 0 : xi > 1 ? 1 : xi;
    return xc * xc * (3.0 - 2.0 * xc);
}
function heightmapSampleNormal(h, row, col) {
    const leftNeigh = [-1, h.sample(col - 1, row), 0];
    const rightNeigh = [1, h.sample(col + 1, row), 0];
    const tan = vec3.create();
    vec3.sub(tan, rightNeigh, leftNeigh);
    vec3.scale(tan, tan, 0.5);
    const upBit = [0, h.sample(col, row - 1), -1];
    const downBit = [0, h.sample(col, row + 1), 1];
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
        for (let col = 0; col < cols; col++) {
            const height = hm.sample(0, col);
            const normal = heightmapSampleNormal(hm, 0, col);
            verts.push(col, height, 0, ...normal);
        }
        for (let row = 1; row < rows; row++) {
            for (let col = 0; col < cols; col++) {
                const height = hm.sample(row, col);
                const normal = heightmapSampleNormal(hm, row, col);
                verts.push(col, height, row, ...normal);
                const i = row * cols + col;
                indis.push(i - cols, i);
            }
            indis.push(0xFFFFFFFF);
        }
        this.vertData = new Float32Array(verts);
        this.indexData = new Uint32Array(indis);
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
}
const CAM_START = [0, 10, 0];
const CAM_ROT_SPEED = TAU / 8; // angular speed
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
export class Sample16 {
    device;
    context;
    center;
    heightmapPipeline;
    viewBg;
    proj;
    mViewProjBuf;
    eyeBuf;
    cam;
    keys;
    canvasFormat;
    zBuffer;
    constructor(device, context, heightMap) {
        this.device = device;
        this.context = context;
        const imageHm = new ImageHeightmap(heightMap, 10);
        const imageHm_chunk = new HeightmapChunk(imageHm, -imageHm.rows / 2, -imageHm.cols / 2, imageHm.rows, imageHm.cols);
        this.center = new HeightmapNode(device, [-imageHm.cols / 2, 0, -imageHm.rows / 2], imageHm_chunk);
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
            size: 3 * 4,
            usage: GPUBufferUsage.UNIFORM,
            mappedAtCreation: true,
        });
        (new Float32Array(this.eyeBuf.getMappedRange())).set([this.cam.model[12], this.cam.model[13], this.cam.model[14]]);
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
        const hmPipelineLayout = device.createPipelineLayout({
            bindGroupLayouts: [
                modelBgLayout,
                viewBgLayout,
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
        if (k.isDown('ControlLeft')) {
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
        pass.setBindGroup(0, this.center.bg);
        pass.setBindGroup(1, this.viewBg);
        pass.setVertexBuffer(0, this.center.mesh.verts);
        pass.setIndexBuffer(this.center.mesh.indis, 'uint32');
        pass.drawIndexed(this.center.mesh.nIndis);
        pass.end();
        const commands = enc.finish();
        this.device.queue.submit([commands]);
    }
}
//# sourceMappingURL=sample.js.map