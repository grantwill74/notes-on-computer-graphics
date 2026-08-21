const floorShaderCode = /*wgsl*/ `
@group(0) @binding(0) var<uniform> mModel: mat4x4<f32>;

@group(1) @binding(0) var tex: texture_2d<f32>;
@group(1) @binding(1) var samp: sampler;

@group(2) @binding(0) var<uniform> mView: mat4x4<f32>;
@group(2) @binding(1) var<uniform> mProj: mat4x4<f32>;

struct VertexOutput {
    @builtin(position) pos: vec4f,
    @location(0) uvs: vec2f,
};

@vertex fn vs(
    @location(0) pos: vec3f,
    @location(1) uvs: vec2f,
) -> VertexOutput
{
    var vo: VertexOutput;
    vo.pos = mProj * mView * mModel * vec4f(pos, 1.0);
    vo.uvs = uvs;
    return vo;
}

@fragment fn fs(vert: VertexOutput) -> @location(0) vec4f {
    return textureSample(tex, samp, vert.uvs);
}
`;
const genMipmapsCode = /*wgsl*/ `
const POS: array<vec2f, 4> = array(
    vec2f(-1,  1), 
    vec2f(-1, -1),
    vec2f( 1,  1),
    vec2f(1, -1)
);

const UV: array<vec2f, 4> = array(
    vec2f(0, 0), vec2f(0, 1),
    vec2f(1, 0), vec2f(1, 1)
);

struct VertexOutput {
    @builtin(position) pos: vec4f,
    @location(0) uv: vec2f,
};

@vertex fn vs(@builtin(vertex_index) vertId: u32)
    -> VertexOutput
{
    var vo: VertexOutput;
    vo.uv = UV[vertId];
    vo.pos = vec4f(POS[vertId], 0, 1);
    return vo;
}

@group(0) @binding(0) var tex: texture_2d<f32>;
@group(0) @binding(1) var samp: sampler;

@fragment fn fs(@location(0) uv: vec2f) -> @location(0) vec4f {
    // return vec4f(0, 1, 0, 1);
    return textureSample(tex, samp, uv);
}
`;
const sphereCode = /*wgsl*/ `
@group(0) @binding(0) var<uniform> mModel: mat4x4<f32>;
@group(2) @binding(0) var<uniform> mView: mat4x4<f32>;
@group(2) @binding(1) var<uniform> mProj: mat4x4<f32>;

@group(1) @binding(0) var samp: sampler;
@group(1) @binding(1) var basetex: texture_2d<f32>;
@group(1) @binding(2) var clouds: texture_2d<f32>;
@group(1) @binding(3) var normalmap: texture_2d<f32>;
@group(1) @binding(4) var specmap: texture_2d<f32>;

@group(3) @binding(0) var<uniform> eye: vec3f;

// hardcoded light values
const light_dir = normalize(vec3f(1, 1, 0));
const ambient = vec3f(0.1, 0.1, 0.1);

struct VertexOutput {
    @builtin(position) pos: vec4f,
    @location(0) uv: vec2f,
    @location(1) eye_off: vec3f,
    @location(2) world_pos: vec3f,
};

@vertex fn vs(
    @location(0) pos: vec3f,
    @location(1) uv: vec2f,
) -> VertexOutput 
{
    var vo: VertexOutput;
    vo.world_pos = (mModel * vec4f(pos, 1.0)).xyz;
    vo.pos = mProj * mView * vec4f(vo.world_pos, 1.0);
    vo.eye_off = eye - vo.world_pos;
    vo.uv = uv;
    return vo;
}

@fragment fn fs(vo: VertexOutput) -> @location(0) vec4f {
    return vec4f(1, 0, 0, 1);
}
`;
import { vec3, mat3, mat4 } from 'gl-matrix';
import { Mesh, genUvSphere } from '../sample14_spheres_and_cubemaps/sample.js';
export async function genCheckerboardTex(device, tileDim, nMipLevels) {
    const dim = tileDim * 2;
    const tex = device.createTexture({
        format: 'rgba8unorm-srgb',
        size: [dim, dim, 1],
        usage: GPUTextureUsage.COPY_DST |
            GPUTextureUsage.TEXTURE_BINDING |
            GPUTextureUsage.RENDER_ATTACHMENT,
        mipLevelCount: nMipLevels,
    });
    const pixels = [];
    for (let row = 0; row < dim; row++) {
        for (let col = 0; col < dim; col++) {
            let c = 0;
            if (row < tileDim && col < tileDim || row >= tileDim && col >= tileDim)
                c = 255;
            pixels.push(c, c, c, 255);
        }
    }
    const texData = new Uint8ClampedArray(pixels);
    const imgData = new ImageData(texData, dim, dim);
    const bitmap = await createImageBitmap(imgData);
    device.queue.copyExternalImageToTexture({ source: bitmap }, { texture: tex, colorSpace: 'srgb', mipLevel: 0 }, { width: dim, height: dim, depthOrArrayLayers: 1 });
    await device.queue.onSubmittedWorkDone();
    return tex;
}
export function createMipmapPipeline(device) {
    const layout = device.createPipelineLayout({
        bindGroupLayouts: [
            device.createBindGroupLayout({
                entries: [
                    { binding: 0, visibility: GPUShaderStage.FRAGMENT, texture: {} },
                    { binding: 1, visibility: GPUShaderStage.FRAGMENT, sampler: {} },
                ]
            })
        ]
    });
    const module = device.createShaderModule({ code: genMipmapsCode });
    return device.createRenderPipeline({
        layout,
        vertex: {
            module,
            buffers: [],
        },
        fragment: {
            module,
            targets: [{
                    format: 'rgba8unorm-srgb',
                }]
        },
        label: 'mipmap generation pipeline',
        primitive: {
            topology: 'triangle-strip',
        }
    });
}
export function genMips(device, tex, nLayers, pipeline) {
    const samp = device.createSampler({
        minFilter: 'linear',
    });
    const enc = device.createCommandEncoder();
    // one render pass per mip layer
    for (let layer = 1; layer < nLayers; layer++) {
        const bg = device.createBindGroup({
            layout: pipeline.getBindGroupLayout(0),
            entries: [
                { binding: 0, resource: tex.createView({
                        baseMipLevel: layer - 1,
                        mipLevelCount: 1,
                    }) },
                { binding: 1, resource: samp }
            ]
        });
        const pass = enc.beginRenderPass({
            colorAttachments: [{
                    loadOp: 'clear',
                    storeOp: 'store',
                    view: tex.createView({
                        baseMipLevel: layer,
                        mipLevelCount: 1,
                    })
                }],
            label: 'pass for mip layer #' + layer
        });
        pass.setPipeline(pipeline);
        pass.setBindGroup(0, bg);
        pass.draw(4);
        pass.end();
    }
    const commands = enc.finish();
    device.queue.submit([commands]);
}
const TAU = 2 * Math.PI;
// these are in turns/second
const CAM_PITCH_PER_SECOND = 0.25;
const CAM_ROLL_PER_SECOND = 0.125;
const CAM_YAW_PER_SECOND = 0.33;
// units per second
const CAM_MOVE_SPEED = 10;
// janky hack to avoid handling keyrepeat properly. I will fix this in 
// the future by tracking the individual keystates
let lastKeyDown;
export class Sample15 {
    device;
    context;
    texChecker;
    texCheckerMip;
    mModel;
    mView;
    mProj;
    texDepth;
    floorVerts;
    sphereMesh;
    bufMatrices;
    bufEye;
    mCam; // camera model matrix
    camPos;
    camPitch;
    camYaw;
    camRoll;
    //vv how much to change cam angle per frame vv
    camPitchAmnt;
    camYawAmnt;
    camRollAmnt;
    camMoveAmnt;
    floorPipeline;
    spherePipeline;
    bgFloorModel;
    bgViewProj;
    bgSphereModel;
    bgFloorTexes;
    bgFloorTexesMip;
    bgFloorTexesNoMip;
    bgSphereTexes;
    bgEye;
    mipMap = false;
    constructor(device, context, texChecker, texCheckerMip) {
        this.device = device;
        this.context = context;
        this.texChecker = texChecker;
        this.texCheckerMip = texCheckerMip;
        const shaderMod = device.createShaderModule({
            code: floorShaderCode,
            label: "textured shader"
        });
        // large flat plane, xyz;uv
        const verts = new Float32Array([
            -100, 0, -100, 0, 0,
            -100, 0, 100, 0, 200,
            100, 0, -100, 200, 0,
            100, 0, 100, 200, 200,
        ]);
        const stride = 3 * 4 + 2 * 4;
        const uvOffset = 3 * 4;
        this.floorVerts = device.createBuffer({
            size: verts.byteLength,
            usage: GPUBufferUsage.VERTEX,
            label: "vertex buffer",
            mappedAtCreation: true,
        });
        (new Float32Array(this.floorVerts.getMappedRange())).set(verts);
        this.floorVerts.unmap();
        this.sphereMesh = genUvSphere(10, 10, 'triangle-list');
        this.texDepth = device.createTexture({
            format: 'depth24plus-stencil8',
            size: { width: context.canvas.width, height: context.canvas.height },
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.COPY_DST,
            label: "depth texture",
        });
        this.mProj = mat4.create();
        mat4.perspectiveZO(this.mProj, TAU / 8, context.canvas.width / context.canvas.height, 1, 128);
        this.mModel = mat4.create();
        this.mView = mat4.create();
        const V = GPUShaderStage.VERTEX;
        const F = GPUShaderStage.FRAGMENT;
        const bgModelLayoutDesc = {
            entries: [
                {
                    binding: 0,
                    visibility: V,
                    buffer: {}
                },
            ],
            label: "matrix bg layout"
        };
        const bgViewProjLayoutDesc = {
            entries: [
                {
                    binding: 0,
                    visibility: V,
                    buffer: {}
                },
                {
                    binding: 1,
                    visibility: V,
                    buffer: {}
                }
            ]
        };
        const bgFloorTexesLayoutDesc = {
            entries: [
                {
                    binding: 0,
                    visibility: F,
                    texture: {}
                },
                {
                    binding: 1,
                    visibility: F,
                    sampler: {}
                }
            ],
            label: "texture bg layout"
        };
        const bgSphereTexesLayoutDesc = {
            entries: [
                {
                    binding: 0,
                    visibility: F,
                    sampler: {}
                },
                {
                    binding: 1,
                    visibility: F,
                    texture: {},
                },
                {
                    binding: 2,
                    visibility: F,
                    texture: {}
                },
                {
                    binding: 3,
                    visibility: F,
                    texture: {},
                },
                {
                    binding: 4,
                    visibility: F,
                    texture: {},
                }
            ]
        };
        const bgEyeLayoutDesc = {
            entries: [{
                    binding: 0,
                    visibility: V,
                    buffer: {}
                }]
        };
        const bgModelLayout = device.createBindGroupLayout(bgModelLayoutDesc);
        const bgViewProjLayout = device.createBindGroupLayout(bgViewProjLayoutDesc);
        const bgFloorTexesLayout = device.createBindGroupLayout(bgFloorTexesLayoutDesc);
        const bgSphereTexesLayout = device.createBindGroupLayout(bgSphereTexesLayoutDesc);
        const bgEyeLayout = device.createBindGroupLayout(bgEyeLayoutDesc);
        this.bufMatrices = device.createBuffer({
            size: 1024,
            usage: GPUBufferUsage.UNIFORM |
                GPUBufferUsage.COPY_DST,
            label: "matrix buffer",
            mappedAtCreation: false,
        });
        this.bufEye = device.createBuffer({
            size: 4 * 4,
            usage: GPUBufferUsage.UNIFORM |
                GPUBufferUsage.COPY_DST,
            label: "eye buffer",
            mappedAtCreation: false,
        });
        this.bgEye = device.createBindGroup({
            entries: [{
                    binding: 0,
                    resource: this.bufEye
                }],
            layout: bgEyeLayout
        });
        this.bgFloorModel = device.createBindGroup({
            layout: bgModelLayout,
            entries: [
                {
                    binding: 0,
                    resource: {
                        buffer: this.bufMatrices,
                        offset: 0,
                        size: 4 * 4 * 4
                    },
                },
            ],
            label: "matrix bind group"
        });
        this.bgViewProj = device.createBindGroup({
            entries: [
                {
                    binding: 0,
                    resource: {
                        buffer: this.bufMatrices,
                        offset: 256,
                        size: 4 * 4 * 4
                    }
                },
                {
                    binding: 1,
                    resource: {
                        buffer: this.bufMatrices,
                        offset: 512,
                        size: 4 * 4 * 4,
                    },
                },
            ],
            layout: bgViewProjLayout
        });
        this.bgSphereModel = device.createBindGroup({
            entries: [{
                    binding: 0,
                    resource: {
                        buffer: this.bufMatrices,
                        offset: 256 * 3,
                        size: 4 * 4 * 4
                    }
                }],
            layout: bgModelLayout
        });
        const sampler = device.createSampler({
            addressModeU: 'repeat',
            addressModeV: 'repeat',
            magFilter: 'linear',
            minFilter: 'linear',
            mipmapFilter: 'linear',
            label: "texture sampler",
            maxAnisotropy: 1,
        });
        this.bgFloorTexesMip = device.createBindGroup({
            layout: bgFloorTexesLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.texCheckerMip
                },
                {
                    binding: 1,
                    resource: sampler
                }
            ],
            label: 'bg mipmapping'
        });
        this.bgFloorTexes = this.bgFloorTexesMip;
        this.bgFloorTexesNoMip = device.createBindGroup({
            layout: bgFloorTexesLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.texChecker
                },
                {
                    binding: 1,
                    resource: sampler
                }
            ],
            label: 'bg no mip'
        });
        this.bgSphereTexes = device.createBindGroup({
            layout: bgSphereTexesLayout,
            entries: [
                {
                    binding: 0,
                    resource: sampler,
                },
                {
                    binding: 1,
                    resource: this.texChecker // for now
                },
                {
                    binding: 2,
                    resource: this.texChecker
                },
                {
                    binding: 3,
                    resource: this.texChecker
                },
                {
                    binding: 4,
                    resource: this.texChecker
                }
            ]
        });
        const floorPipelineLayout = device.createPipelineLayout({
            bindGroupLayouts: [
                bgModelLayout,
                bgFloorTexesLayout,
                bgViewProjLayout,
            ]
        });
        const spherePipelineLayout = device.createPipelineLayout({
            bindGroupLayouts: [
                bgModelLayout,
                bgSphereTexesLayout,
                bgViewProjLayout,
                bgEyeLayout
            ],
        });
        this.floorPipeline = device.createRenderPipeline({
            layout: floorPipelineLayout,
            vertex: {
                module: shaderMod,
                buffers: [
                    {
                        arrayStride: stride,
                        stepMode: 'vertex',
                        attributes: [
                            // xyz
                            {
                                format: 'float32x3',
                                offset: 0,
                                shaderLocation: 0
                            },
                            // uv
                            {
                                format: 'float32x2',
                                offset: uvOffset,
                                shaderLocation: 1
                            }
                        ]
                    }
                ],
            },
            fragment: {
                module: shaderMod,
                targets: [
                    {
                        format: context.getCurrentTexture().format,
                    }
                ],
            },
            depthStencil: {
                format: 'depth24plus-stencil8',
                depthWriteEnabled: true,
                depthCompare: 'less-equal',
            },
            primitive: {
                cullMode: 'none',
                frontFace: 'ccw',
                topology: 'triangle-strip',
            },
            label: "tex quad pipeline"
        });
        const sphereShaderMod = device.createShaderModule({ code: sphereCode });
        this.spherePipeline = device.createRenderPipeline({
            layout: spherePipelineLayout,
            vertex: {
                module: sphereShaderMod,
                buffers: [{
                        arrayStride: 3 * 4 + 2 * 4,
                        attributes: [
                            {
                                format: 'float32x3',
                                offset: 0,
                                shaderLocation: 0,
                            },
                            {
                                format: 'float32x2',
                                offset: 3 * 4,
                                shaderLocation: 1,
                            }
                        ]
                    }]
            }
        });
        this.camPos = vec3.fromValues(0, 10, -10);
        this.camPitch = 0;
        this.camRoll = 0;
        this.camYaw = 0.0;
        this.camPitchAmnt = this.camYawAmnt = this.camRollAmnt = 0;
        this.camMoveAmnt = vec3.create();
        this.mCam = mat4.create();
    }
    camAddAngles(yaw, pitch, roll) {
        this.camYaw += yaw;
        this.camPitch += pitch;
        this.camRoll += roll;
    }
    setMipMapping(on) {
        this.mipMap = on;
        this.bgFloorTexes = on ? this.bgFloorTexesMip : this.bgFloorTexesNoMip;
    }
    setAniso(maxAnisotropy) {
        // optimization: we could put the sampler in its own bind group, since
        // the texture doesn't change. Given how rarely we change the 
        // level of anisotropic filtering I don't bother, but we could
        // just make all the sampler bind groups at once.
        const sampler = this.device.createSampler({
            addressModeU: 'repeat',
            addressModeV: 'repeat',
            magFilter: 'linear',
            minFilter: 'linear',
            mipmapFilter: 'linear',
            label: "texture sampler",
            maxAnisotropy,
        });
        this.bgFloorTexesMip = this.device.createBindGroup({
            entries: [
                {
                    binding: 0,
                    resource: this.texCheckerMip.createView(),
                },
                {
                    binding: 1,
                    resource: sampler
                }
            ],
            layout: this.floorPipeline.getBindGroupLayout(1),
            label: 'mip layout'
        });
        if (this.mipMap) {
            this.bgFloorTexes = this.bgFloorTexesMip;
        }
    }
    update() {
        this.camPitch += this.camPitchAmnt / 60;
        this.camRoll += this.camRollAmnt / 60;
        this.camYaw += this.camYawAmnt / 60;
        vec3.scaleAndAdd(this.camPos, this.camPos, this.camMoveAmnt, CAM_MOVE_SPEED / 60.0);
        mat4.identity(this.mCam);
        mat4.translate(this.mCam, this.mCam, this.camPos);
        mat4.rotateY(this.mCam, this.mCam, this.camYaw * TAU);
        mat4.rotateX(this.mCam, this.mCam, this.camPitch * TAU);
        mat4.rotateZ(this.mCam, this.mCam, this.camRoll * TAU);
        mat4.invert(this.mView, this.mCam);
        // build the matrix array. total size: 1024 bytes
        // 64 floats is 256, which is the alignment
        const matArray = new Float32Array(64 * 4);
        matArray.set(this.mModel);
        matArray.set(this.mView, 64);
        matArray.set(this.mProj, 64 * 2);
        // not using normal matrix
        this.device.queue.writeBuffer(this.bufMatrices, 0, matArray);
    }
    forward() {
        const f = vec3.fromValues(this.mCam[8], this.mCam[9], this.mCam[10]);
        vec3.negate(f, f);
        return f;
    }
    up() {
        return vec3.fromValues(this.mCam[4], this.mCam[5], this.mCam[6]);
    }
    right() {
        return vec3.fromValues(this.mCam[0], this.mCam[1], this.mCam[2]);
    }
    startUpdating() {
        setInterval(this.update.bind(this), 1000 / 60);
        addEventListener('keydown', (ev) => {
            if (ev.code == lastKeyDown) {
                return;
            }
            switch (ev.code) {
                case 'ArrowUp':
                    this.camPitchAmnt = -CAM_PITCH_PER_SECOND;
                    break;
                case 'ArrowDown':
                    this.camPitchAmnt = CAM_PITCH_PER_SECOND;
                    break;
                case 'ArrowLeft':
                    this.camYawAmnt = CAM_YAW_PER_SECOND;
                    break;
                case 'ArrowRight':
                    this.camYawAmnt = -CAM_YAW_PER_SECOND;
                    break;
                case 'KeyQ':
                    this.camRollAmnt = CAM_ROLL_PER_SECOND;
                    break;
                case 'KeyE':
                    this.camRollAmnt = -CAM_ROLL_PER_SECOND;
                    break;
                case 'KeyW':
                    vec3.add(this.camMoveAmnt, this.camMoveAmnt, this.forward());
                    break;
                case 'KeyS':
                    vec3.sub(this.camMoveAmnt, this.camMoveAmnt, this.forward());
                    break;
                case 'KeyA':
                    vec3.sub(this.camMoveAmnt, this.camMoveAmnt, this.right());
                    break;
                case 'KeyD':
                    vec3.add(this.camMoveAmnt, this.camMoveAmnt, this.right());
                    break;
                case 'Space':
                    vec3.add(this.camMoveAmnt, this.camMoveAmnt, this.up());
                    break;
                case 'KeyC':
                    vec3.sub(this.camMoveAmnt, this.camMoveAmnt, this.up());
                    break;
            }
            lastKeyDown = ev.code;
        });
        addEventListener('keyup', (ev) => {
            switch (ev.code) {
                case 'ArrowUp':
                    this.camPitchAmnt = 0;
                    break;
                case 'ArrowDown':
                    this.camPitchAmnt = 0;
                    break;
                case 'ArrowLeft':
                    this.camYawAmnt = 0;
                    break;
                case 'ArrowRight':
                    this.camYawAmnt = 0;
                    break;
                case 'KeyQ':
                    this.camRollAmnt = 0;
                    break;
                case 'KeyE':
                    this.camRollAmnt = 0;
                    break;
                case 'KeyW':
                    this.camMoveAmnt = vec3.create();
                    break;
                case 'KeyS':
                    this.camMoveAmnt = vec3.create();
                    break;
                case 'KeyA':
                    this.camMoveAmnt = vec3.create();
                    break;
                case 'KeyD':
                    this.camMoveAmnt = vec3.create();
                    break;
                case 'Space':
                    this.camMoveAmnt = vec3.create();
                    break;
                case 'KeyC':
                    this.camMoveAmnt = vec3.create();
                    break;
            }
            lastKeyDown = undefined;
        });
    }
    render() {
        const encoder = this.device.createCommandEncoder();
        const pass = encoder.beginRenderPass({
            colorAttachments: [
                {
                    loadOp: 'clear',
                    storeOp: 'store',
                    view: this.context.getCurrentTexture(),
                    clearValue: { r: 0.7, g: 0.8, b: 0.9, a: 1.0 },
                    // resolveTarget: this.context.getCurrentTexture(),
                },
            ],
            depthStencilAttachment: {
                view: this.texDepth,
                depthClearValue: 1.0,
                depthLoadOp: 'clear',
                depthStoreOp: 'store',
                stencilLoadOp: 'clear',
                stencilStoreOp: 'discard',
                stencilClearValue: 0,
            }
        });
        pass.setViewport(0, 0, this.context.canvas.width, this.context.canvas.height, 0, 1);
        pass.setPipeline(this.floorPipeline);
        pass.setVertexBuffer(0, this.floorVerts);
        pass.setBindGroup(0, this.bgFloorModel);
        pass.setBindGroup(1, this.bgFloorTexes);
        pass.setBindGroup(2, this.bgViewProj);
        pass.draw(4);
        pass.end();
        this.device.queue.submit([encoder.finish()]);
    }
    startRendering() {
        const rend = (_now) => {
            this.render();
            requestAnimationFrame(rend);
        };
        rend(performance.now());
    }
}
//# sourceMappingURL=sample.js.map