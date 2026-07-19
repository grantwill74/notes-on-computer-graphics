const shaderCode = /*wgsl*/`
@group(0) @binding(0)
var<uniform> model: mat4x4<f32>;

@group(1) @binding(0)
var<uniform> viewProj: mat4x4<f32>;

struct VertexOutput {
    @builtin(position) pos: vec4f,
    @location(0) color: vec4f,
};

@vertex fn vs(
    @location(0) pos: vec3f,
    @location(1) color: vec3f
) -> VertexOutput
{
    var vo: VertexOutput;
    vo.pos = viewProj * model * vec4f(pos, 1.0);
    vo.color = vec4f(color, 1.0);
    return vo;
}

@fragment fn fs(vo: VertexOutput) -> @location(0) vec4f {
    // you can use the depth to choose the color to demonstrate the 
    // depth buffer in action
    //return vec4f(vo.pos.zzz, 1);

    return vo.color;
}
`;

import { mat4, vec3 } from "gl-matrix"

export class SimpleNode {
    yaw: number = 0;
    pitch: number = 0;
    // roll: number = 0; this is for your homework!
    pos: vec3 = vec3.fromValues(0, 0, 0);
    scale: vec3 = vec3.fromValues(1, 1, 1);

    matrix: mat4;
    matrixBuf: GPUBuffer;
    matrixBg: GPUBindGroup;

    mesh: GPUBuffer | undefined;

    name: string;

    constructor(name: string, device: GPUDevice, layout: GPUBindGroupLayout) {
        this.matrix = mat4.create();
        this.name = name;

        this.matrixBuf = device.createBuffer({
            size: 16 * 4,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
            mappedAtCreation: false,
            label: name + " matrix buffer",
        });

        // create a unique bind group for this node
        this.matrixBg = device.createBindGroup({
            entries: [{
                binding: 0,
                resource: this.matrixBuf,
            }],
            layout,
            label: "bg: " + name,
        });
    }

    vertData: GPUBuffer | undefined;

    updateMatrix(device: GPUDevice): void {
        mat4.identity(this.matrix);
        mat4.translate(this.matrix, this.matrix, this.pos);
        mat4.rotateY(this.matrix, this.matrix, this.yaw * TAU);
        mat4.rotateX(this.matrix, this.matrix, this.pitch * TAU);
        mat4.scale(this.matrix, this.matrix, this.scale);

        device.queue.writeBuffer(
            this.matrixBuf, 0,
            new Float32Array(this.matrix));
    }

    // assumes matrix is up to date
    forward(): vec3 {
        return vec3.fromValues(this.matrix[8], this.matrix[9], this.matrix[10]);
    }

    right(): vec3 {
        return vec3.fromValues(this.matrix[0], this.matrix[1], this.matrix[2]);
    }

    up(): vec3 {
        return vec3.fromValues(this.matrix[4], this.matrix[5], this.matrix[6]);
    }
}

function cubeMeshVerts(): Float32Array {
    return new Float32Array([
        -1, -1,  1,  1, 0, 0,
        1, -1,  1,  1, 0, 0,
        1,  1,  1,  1, 0, 0,
        -1, -1,  1,  1, 0, 0,
        1,  1,  1,  1, 0, 0,
        -1,  1,  1,  1, 0, 0,

        1,  1,  1,  0, 1, 0,
        1, -1,  1,  0, 1, 0,
        1, -1, -1,  0, 1, 0,
        1, -1, -1,  0, 1, 0,
        1,  1, -1,  0, 1, 0,
        1,  1,  1,  0, 1, 0,

        -1,  1, -1,  0, 0, 1,
        1,  1, -1,  0, 0, 1,
        1, -1, -1,  0, 0, 1,
        1, -1, -1,  0, 0, 1,
        -1, -1, -1,  0, 0, 1,
        -1,  1, -1,  0, 0, 1,

        -1, -1, -1,  1, 1, 0,
        -1, -1,  1,  1, 1, 0,
        -1,  1,  1,  1, 1, 0,
        -1,  1,  1,  1, 1, 0,
        -1,  1, -1,  1, 1, 0,
        -1, -1, -1,  1, 1, 0,

        -1,  1,  1,  1, 0, 1,
        1,  1,  1,  1, 0, 1,
        1,  1, -1,  1, 0, 1,
        -1,  1,  1,  1, 0, 1,
        1,  1, -1,  1, 0, 1,
        -1,  1, -1,  1, 0, 1,

        -1, -1,  1,  0, 1, 1,
        -1, -1, -1,  0, 1, 1,
        1, -1, -1,  0, 1, 1,
        1, -1, -1,  0, 1, 1,
        1, -1,  1,  0, 1, 1,
        -1, -1,  1,  0, 1, 1,
    ]);
}

const TAU = Math.PI * 2;
const FOV_X = (1/6) * TAU

const CUBE1_ROT_SPEED = 0.25;
const CUBE2_NOD_AMP = .05;
const CUBE2_NOD_SPEED = 1 / 4;
const CUBE3_WAVE_SPEED = 1 / 2;
const CUBE3_WAVE_AMP = 1;
const CAM_MOVE_SPEED = 5;       // units per second        
const CAM_ROTATE_SPEED = 1 / 6; // turns per second

export class Keys {
    down: Set<string> = new Set();

    constructor() {
        // start listening 
        addEventListener('keydown', (event) => {
            this.down.add(event.code);
        });
        addEventListener('keyup', (event) => {
            this.down.delete(event.code);
        });
    }

    isDown(code: string): boolean {
        return this.down.has(code);
    }
}

export class Sample09 {
    device: GPUDevice;
    context: GPUCanvasContext;

    cubeBuf: GPUBuffer;

    cube1: SimpleNode;
    cube2: SimpleNode;
    cube3: SimpleNode;
    camera: SimpleNode;

    projection: mat4;
    view: mat4;
    viewProj: mat4;
    matViewProj: GPUBuffer;
    bgMatViewProj: GPUBindGroup;

    lastRender: number;

    canvasFormat: GPUTextureFormat;
    pipeline: GPURenderPipeline;
    depthBuffer: GPUTexture;

    keys: Keys;

    constructor(
        device: GPUDevice,
        context: GPUCanvasContext,
    ) {
        this.device = device;
        this.context = context;

        const cubeVerts = cubeMeshVerts();
        this.cubeBuf = device.createBuffer({
            size: cubeVerts.byteLength,
            usage: GPUBufferUsage.VERTEX,
            mappedAtCreation: true,
            label: "cube mesh buffer"
        });
        (new Float32Array(this.cubeBuf.getMappedRange())).set(cubeVerts);
        this.cubeBuf.unmap();

        const nodeLayout = device.createBindGroupLayout({
            entries: [{
                binding: 0,
                visibility: GPUShaderStage.VERTEX,
                buffer: {}
            }]
        });

        this.cube1 = new SimpleNode("cube 1", device, nodeLayout);
        this.cube1.pos[0] = -3;
        
        this.cube2 = new SimpleNode("cube 2", device, nodeLayout);
        this.cube2.pos[0] = 0;

        this.cube3 = new SimpleNode("cube 3", device, nodeLayout);
        this.cube3.pos[0] = 3;

        this.camera = new SimpleNode("camera", device, nodeLayout);
        this.camera.pos[2] = 10;

        const aspectR = context.canvas.width / context.canvas.height;

        this.projection = mat4.create();
        mat4.perspectiveZO(this.projection, FOV_X / aspectR, aspectR, 1, 64);
        this.view = mat4.create();

        this.matViewProj = device.createBuffer({
            size: 16 * 4,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
            label: "viewProj matrix buffer",
            mappedAtCreation: false,
        });

        this.viewProj = mat4.create();

        const viewProjLayout = device.createBindGroupLayout({
            entries: [{
                binding: 0,
                visibility: GPUShaderStage.VERTEX,
                buffer: {},
            }]
        });
        this.bgMatViewProj = device.createBindGroup({
            layout: viewProjLayout,
            entries: [{
                binding: 0,
                resource: this.matViewProj
            }]
        });

        this.lastRender = performance.now();

        this.canvasFormat = 
            (context.getCurrentTexture().format + '-srgb') as GPUTextureFormat;

        const pipelineLayout = device.createPipelineLayout({
            bindGroupLayouts: [nodeLayout, viewProjLayout],
        });

        const shaderMod = device.createShaderModule({code: shaderCode});

        this.depthBuffer = device.createTexture({
            format: 'depth24plus-stencil8',
            size: {width: context.canvas.width, height: context.canvas.height},
            usage: GPUTextureUsage.RENDER_ATTACHMENT,
        });

        this.pipeline = device.createRenderPipeline({
            layout: pipelineLayout,
            vertex: {
                module: shaderMod,
                buffers: [{
                    arrayStride: 3 * 4 + 3 * 4,
                    attributes: [
                        { // position
                            format: 'float32x3',
                            offset: 0,
                            shaderLocation: 0,
                        },
                        { // color
                            format: 'float32x3',
                            offset: 3 * 4,
                            shaderLocation: 1,
                        }
                    ]
                }]
            },
            fragment: {
                module: shaderMod,
                targets: [{
                    format: this.canvasFormat
                }]
            },
            depthStencil: {
                format: 'depth24plus-stencil8',
                depthCompare: 'less-equal',
                depthWriteEnabled: true,
            },
            primitive: {
                cullMode: 'back',
                frontFace: 'ccw',
                topology: 'triangle-list',
            }
        });

        this.keys = new Keys();
    }

    cubePhase = 0;

    update(dt: number): void {
        this.cube1.yaw += (CUBE1_ROT_SPEED * dt) % 1;
        this.cube2.pitch = Math.sin(CUBE2_NOD_SPEED * this.cubePhase * TAU) * CUBE2_NOD_AMP;
        this.cubePhase += dt;
        this.cubePhase %= 4;
        this.cube3.pos[1] = Math.sin(this.cubePhase * CUBE3_WAVE_SPEED * TAU) * CUBE3_WAVE_AMP;

        if (this.keys.isDown('KeyW')) {
            const forward = this.camera.forward();
            vec3.scaleAndAdd(this.camera.pos, this.camera.pos, forward, -CAM_MOVE_SPEED * dt);
        }
        if (this.keys.isDown('KeyS')) {
            const forward = this.camera.forward();
            vec3.scaleAndAdd(this.camera.pos, this.camera.pos, forward, CAM_MOVE_SPEED * dt);
        }
        if (this.keys.isDown('Space')) {
            const up = this.camera.up();
            vec3.scaleAndAdd(this.camera.pos, this.camera.pos, up, CAM_MOVE_SPEED * dt);
        }
        if (this.keys.isDown('KeyC')) {
            const up = this.camera.up();
            vec3.scaleAndAdd(this.camera.pos, this.camera.pos, up, -CAM_MOVE_SPEED * dt);
        }
        if (this.keys.isDown('KeyA')) {
            const right = this.camera.right();
            vec3.scaleAndAdd(this.camera.pos, this.camera.pos, right, -CAM_MOVE_SPEED * dt);
        }
        if (this.keys.isDown('KeyD')) {
            const right = this.camera.right();
            vec3.scaleAndAdd(this.camera.pos, this.camera.pos, right, CAM_MOVE_SPEED * dt);
        }
        if (this.keys.isDown('ArrowUp')) {
            this.camera.pitch += -CAM_ROTATE_SPEED * dt;
            this.camera.pitch %= 1;
        }
        if (this.keys.isDown('ArrowDown')) {
            this.camera.pitch += CAM_ROTATE_SPEED * dt;
            this.camera.pitch %= 1;
        }
        if (this.keys.isDown('ArrowLeft')) {
            this.camera.yaw += CAM_ROTATE_SPEED * dt;
            this.camera.yaw %= 1;
        }
        if (this.keys.isDown('ArrowRight')) {
            this.camera.yaw += -CAM_ROTATE_SPEED * dt;
            this.camera.yaw %= 1;
        }

        this.cube1.updateMatrix(this.device);
        this.cube2.updateMatrix(this.device);
        this.cube3.updateMatrix(this.device);
        this.camera.updateMatrix(this.device);

        mat4.invert(this.view, this.camera.matrix);
        mat4.mul(this.viewProj, this.projection, this.view);

        this.device.queue.writeBuffer(this.matViewProj, 0,
            new Float32Array(this.viewProj));
    }

    render(now: number): void {
        const dt = (now - this.lastRender) / 1000;
        this.lastRender = now;
        this.update(dt);

        const encoder = this.device.createCommandEncoder();
        const pass = encoder.beginRenderPass({
            colorAttachments: [{
                loadOp: 'clear',
                storeOp: 'store',
                view: this.context.getCurrentTexture().createView({ 
                    format: this.canvasFormat
                }),
                clearValue: {r: .7, g: .8, b: .9, a: 1},
            }],
            depthStencilAttachment: {
                view: this.depthBuffer.createView(),
                depthClearValue: 1,
                depthLoadOp: 'clear',
                depthReadOnly: false,
                depthStoreOp: 'store',
                stencilReadOnly: true,
            }
        });
        const canv = this.context.canvas;
        pass.setViewport(0, 0, canv.width, canv.height, 0, 1);
        pass.setPipeline(this.pipeline);

        // view proj, stays the same for the whole pass
        pass.setBindGroup(1, this.bgMatViewProj);
        
        // all cubes have the same vertices
        pass.setVertexBuffer(0, this.cubeBuf);

        // cube 1
        pass.setBindGroup(0, this.cube1.matrixBg);
        pass.draw(36);

        // cube 2
        pass.setBindGroup(0, this.cube2.matrixBg);
        pass.draw(36);

        // cube 3
        pass.setBindGroup(0, this.cube3.matrixBg);
        pass.draw(36);

        pass.end();

        const commands = encoder.finish();
        this.device.queue.submit([commands]);
    }

    startRendering(): void {
        const renderAndRequeue = (now: number) => {
            this.render(now);
            requestAnimationFrame(renderAndRequeue);
        }
        requestAnimationFrame(renderAndRequeue);
    }
}