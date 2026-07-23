const shaderCode = /*wgsl*/ `
@group(0) @binding(0) var<uniform> model: mat4x4<f32>;
@group(0) @binding(1) var<uniform> base_color: vec3f;

@group(1) @binding(0) var<uniform> proj: mat4x4<f32>;

// disclosure: the original shader used a screen space effect. the idea to use
// model space position as the seed and then quantize came from an LLM. 
struct VertexOutput {
    @builtin(position) pos: vec4f,
    @location(0) model_pos: vec3f,
};

@vertex fn vs(@location(0) pos: vec3f) -> VertexOutput {
    var vo: VertexOutput;
    vo.pos = proj * model * vec4f(pos, 1.0);
    vo.model_pos = pos;
    return vo;
}

const CELL_SIZE = 0.03125; // group together "pixels" in model space for quantization 
@fragment fn fs(vo: VertexOutput) -> @location(0) vec4f {
    // brightness adjustment: up to 50% less than base color
    let cell = floor(vo.model_pos / CELL_SIZE) * CELL_SIZE;
    let rand = hash3D(cell);
    let brightness = rand.x / 4 + 0.75;
    let color = brightness * base_color;
    return vec4f(color, 1.0);
}

// from: https://dekoolecentrale.nl/wgsl-fns/hash3D
fn hash3D(p: vec3<f32>) -> vec3<f32> {
  var p3 = fract(p * vec3<f32>(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yxz + 33.33);
  return fract((p3.xxy + p3.yxx) * p3.zyx) * 2.0 - 1.0;
}
// the above snippet uses "swizzling". p3.xxy means "create a new vector
// where the x component becomes the x and y component, and the y component
// becomes the z component. p3.zyx flips the order entirely.
`;
import { vec3, mat4 } from 'gl-matrix';
export class PositionMesh {
    indices;
    positions;
    nVerts;
    topology;
    stride = 6 * 4; // 3 position floats, 3 color floats
    name;
    constructor(topo, indices, positions, name) {
        this.indices = indices;
        this.positions = positions;
        this.nVerts = positions.length;
        this.topology = topo;
        this.name = name ?? 'unnamed'; //'unnamed' will be used if name is undefined
    }
}
function simpleCubeMesh() {
    // vec3 is just a wrapper type around a tuple of 3 values.
    // we can construct them like this:
    const positions = [
        [-1, 1, 1], // 0
        [-1, -1, 1], // 1
        [1, 1, 1], // 2
        [1, -1, 1], // 3
        [1, 1, -1], // 4
        [1, -1, -1], // 5
        [-1, 1, -1], // 6
        [-1, -1, -1], // 7
    ];
    const indis = [
        0, 1, 2, 3,
        4, 5,
        6, 7,
        0, 1, 0xFFFFFFFF,
        0, 2, 6, 4, 0xFFFFFFFF,
        3, 1, 5, 7
    ];
    return new PositionMesh('triangle-strip', indis, positions, 'cube');
}
class LoadedPositionMesh {
    vertexBuffer;
    indexBuffer;
    nVerts;
    nIndis;
    topology;
    constructor(device, data) {
        this.nVerts = data.nVerts;
        this.nIndis = data.indices.length;
        this.topology = data.topology;
        const vertexData = [];
        for (let i = 0; i < data.nVerts; i++) {
            vertexData.push(...data.positions[i]);
        }
        this.vertexBuffer = device.createBuffer({
            size: data.stride * this.nVerts,
            usage: GPUBufferUsage.VERTEX,
            mappedAtCreation: true,
            label: 'verts: ' + data.name
        });
        (new Float32Array(this.vertexBuffer.getMappedRange())).set(vertexData);
        this.vertexBuffer.unmap();
        this.indexBuffer = device.createBuffer({
            size: data.indices.length * 4,
            usage: GPUBufferUsage.INDEX,
            label: 'indis: ' + data.name,
            mappedAtCreation: true,
        });
        (new Uint32Array(this.indexBuffer.getMappedRange())).set(data.indices);
        this.indexBuffer.unmap();
    }
}
export class SceneNode {
    // note: we're not using yaw, pitch, or roll here. instead we're just storing
    // the matrix. the upside is that it's simpler. The downside is that the 
    // rotations will gradually cause matrix drift if it isn't renormalized.
    // if this is a problem, you can every so often do this:
    // https://en.wikipedia.org/wiki/Gram%E2%80%93Schmidt_process
    // that is, follow the algorithm to get 3 new basis vectors for rotation, and 
    // leave position alone.
    // but make sure the handedness stays the same after: it might flip. flip one 
    // basis vector if handedness is left.
    // this is the matrix that includes all the parent transformations
    finalMatrix = mat4.create();
    children = [];
    parent;
    color = [1, 1, 1];
    // this matrix refers to the object relative to its parent.
    // it is used to compute the 'finalMatrix' field above, which is the final matrix.
    localMatrix = mat4.create();
    finalBuf;
    colorBuf;
    modelBg;
    mesh;
    name;
    constructor(device, modelColorLayout, name) {
        const descModel = {
            size: 4 * 16,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
            mappedAtCreation: false
        };
        if (name)
            descModel.label = name + ' model';
        this.finalBuf = device.createBuffer(descModel);
        const descColor = {
            size: 4 * 4,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
            mappedAtCreation: false
        };
        if (name)
            descColor.label = name + ' color';
        this.colorBuf = device.createBuffer(descColor);
        this.modelBg = device.createBindGroup({
            layout: modelColorLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.finalBuf
                },
                {
                    binding: 1,
                    resource: this.colorBuf
                }
            ]
        });
        this.updateData(device);
        this.name = name;
    }
    updateData(device) {
        const parentMatrix = this.parent?.finalMatrix ?? mat4.create();
        mat4.mul(this.finalMatrix, parentMatrix, this.localMatrix);
        device.queue.writeBuffer(this.finalBuf, 0, new Float32Array(this.finalMatrix));
        device.queue.writeBuffer(this.colorBuf, 0, new Float32Array(this.color));
        for (let child of this.children) {
            child.updateData(device);
        }
    }
    move(pos) {
        mat4.translate(this.localMatrix, this.localMatrix, pos);
    }
    rotateX(amount) {
        mat4.rotateX(this.localMatrix, this.localMatrix, amount);
    }
    rotateY(amount) {
        mat4.rotateY(this.localMatrix, this.localMatrix, amount);
    }
    rotateZ(amount) {
        mat4.rotateZ(this.localMatrix, this.localMatrix, amount);
    }
    scale(amount) {
        mat4.scale(this.localMatrix, this.localMatrix, amount);
    }
    addChild(device, layout, name) {
        const child = new SceneNode(device, layout, name);
        child.parent = this;
        this.children.push(child);
        return child;
    }
}
const TAU = Math.PI * 2;
const FOV = TAU / 6;
const BASE_ROT_SPEED = TAU / 16;
const SIDE_TO_SIDE_AMP = 5;
const SIDE_TO_SIDE_PERIOD = TAU / 16;
const PULSE_PERIOD = TAU / 4;
const PULSE_SCALE = 4;
export class Sample11 {
    device;
    context;
    cube;
    projBuf;
    projBg;
    pipeline;
    zBuffer;
    format;
    root;
    lastUpdate = performance.now();
    constructor(device, context) {
        this.device = device;
        this.context = context;
        this.cube = new LoadedPositionMesh(device, simpleCubeMesh());
        const shaderMod = device.createShaderModule({ code: shaderCode });
        const projLayout = device.createBindGroupLayout({
            entries: [{
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {}
                }]
        });
        const modelColorLayout = device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {}
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: {}
                },
            ]
        });
        const pipelineLayout = device.createPipelineLayout({
            bindGroupLayouts: [modelColorLayout, projLayout],
        });
        this.format = (context.getCurrentTexture().format + '-srgb');
        const canv = context.canvas;
        this.zBuffer = device.createTexture({
            format: 'depth24plus-stencil8',
            size: { width: canv.width, height: canv.height },
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.pipeline = device.createRenderPipeline({
            layout: pipelineLayout,
            vertex: {
                module: shaderMod,
                buffers: [{
                        arrayStride: 4 * 3,
                        attributes: [{
                                format: 'float32x3',
                                offset: 0,
                                shaderLocation: 0,
                            }]
                    }]
            },
            fragment: {
                module: shaderMod,
                targets: [{
                        format: this.format,
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
                stripIndexFormat: 'uint32',
                topology: 'triangle-strip',
            }
        });
        const aspectR = canv.width / canv.height;
        const projMat = mat4.create();
        mat4.perspectiveZO(projMat, FOV / aspectR, aspectR, 1, 128);
        mat4.translate(projMat, projMat, [0, 0, -20]);
        this.projBuf = device.createBuffer({
            size: 4 * 16,
            usage: GPUBufferUsage.UNIFORM,
            label: 'projection matrix buffer',
            mappedAtCreation: true
        });
        (new Float32Array(this.projBuf.getMappedRange())).set(projMat);
        this.projBuf.unmap();
        this.projBg = device.createBindGroup({
            layout: projLayout,
            entries: [{
                    binding: 0,
                    resource: this.projBuf
                }]
        });
        this.root = new SceneNode(device, modelColorLayout, "root cube");
        this.root.mesh = this.cube;
        const right = this.root.addChild(device, modelColorLayout, "right cube");
        right.mesh = this.cube;
        right.move([7, 0, 0]);
        right.scale([.5, .5, .5]);
        right.color = [1, 0, 0];
        const left = this.root.addChild(device, modelColorLayout, "left empty node");
        left.move([-7, 0, 0]);
        left.scale([.5, .5, .5]);
        // left.color = [0, 1, 0];
        // note: these are relative to their parents
        const left_c1 = left.addChild(device, modelColorLayout, "left child 1");
        left_c1.move([-3, 0, 0]);
        left_c1.scale([.5, .5, .5]);
        left_c1.color = [0, 1, 0];
        left_c1.mesh = this.cube;
        const left_c2 = left.addChild(device, modelColorLayout, "left child 2");
        left_c2.move([3, 0, 0]);
        left_c2.scale([.75, .75, .75]);
        left_c2.color = [0.25, 0.75, 0.75];
        left_c2.mesh = this.cube;
        const bot = this.root.addChild(device, modelColorLayout, "bottom cube");
        bot.mesh = this.cube;
        bot.move([0, -7, 0]);
        bot.scale([.5, .5, .5]);
        bot.color = [0, 0, 1];
        const right_c1 = right.addChild(device, modelColorLayout, "right child 1");
        right_c1.mesh = this.cube;
        right_c1.move([3, 0, 0]);
        right_c1.scale([.5, .5, .5]); // half the size of its parent, which is half the size of root
        right_c1.color = [1, 1, 0];
        const right_c2 = right.addChild(device, modelColorLayout, "right child 2");
        right_c2.mesh = this.cube;
        right_c2.move([-3, 0, 0]);
        right_c2.scale([.5, .5, .5]);
        right_c2.color = [0, 1, 1];
        const bot_c1 = bot.addChild(device, modelColorLayout, "bottom child");
        bot_c1.mesh = this.cube;
        bot_c1.move([0, -3, 0]);
        bot_c1.scale([.5, .5, .5]);
        bot_c1.color = [1, 0, 1];
        this.root.updateData(device);
    }
    startRendering() {
        const renderAndRequeue = (now) => {
            this.render(now);
            requestAnimationFrame(renderAndRequeue);
        };
        requestAnimationFrame(renderAndRequeue);
    }
    update(t, dt) {
        let stack = [this.root];
        while (stack.length > 0) {
            const cur = stack.pop();
            stack = stack.concat(cur.children);
            cur.rotateX(BASE_ROT_SPEED * dt / 3);
            cur.rotateY(BASE_ROT_SPEED * dt);
            cur.rotateZ(BASE_ROT_SPEED * dt / 4);
            // bottom gets to shrink/grow
            if (cur.name == 'bottom cube') {
                // this is a goofy and not mathematically-sound way to pulse the cube.
                // since we don't store an absolute scale, it's awkward to extract the 
                // scale component to ensure it doesn't blow up.
                // I settle for having it be near 1 each frame.
                const scale = 1 + Math.sin(PULSE_PERIOD * t) * PULSE_SCALE * dt / TAU;
                cur.scale([scale, scale, scale]);
            }
            // spin this one even more
            else if (cur.name == 'left empty node') {
                cur.rotateX(3 * BASE_ROT_SPEED * dt / 3);
                cur.rotateY(3 * BASE_ROT_SPEED * dt);
                cur.rotateZ(3 * BASE_ROT_SPEED * dt / 4);
            }
        }
        const rootX = Math.sin(SIDE_TO_SIDE_PERIOD * t) * SIDE_TO_SIDE_AMP;
        this.root.localMatrix[12] = rootX; // set x coordinate 
        this.root.updateData(this.device);
    }
    render(now) {
        const dt = (now - this.lastUpdate) / 1000;
        this.lastUpdate = now;
        this.update(now / 1000, dt);
        const dev = this.device;
        const con = this.context;
        const encoder = dev.createCommandEncoder();
        const pass = encoder.beginRenderPass({
            colorAttachments: [{
                    loadOp: 'clear',
                    storeOp: 'store',
                    view: con.getCurrentTexture().createView({
                        format: this.format
                    }),
                    clearValue: { r: .7, g: .8, b: .9, a: 1 }
                }],
            depthStencilAttachment: {
                view: this.zBuffer,
                depthLoadOp: 'clear',
                depthClearValue: 1,
                depthStoreOp: 'store',
                depthReadOnly: false,
                stencilReadOnly: true
            }
        });
        pass.setViewport(0, 0, con.canvas.width, con.canvas.height, 0, 1);
        pass.setPipeline(this.pipeline);
        pass.setBindGroup(1, this.projBg);
        let stack = [this.root];
        while (stack.length > 0) {
            const top = stack.pop();
            stack = stack.concat(top.children);
            if (!top.mesh)
                continue;
            // technically, since the nodes all have the same mesh, we don't 
            // really need this, and it would be faster to only set it once.
            pass.setIndexBuffer(top.mesh.indexBuffer, 'uint32');
            pass.setVertexBuffer(0, top.mesh.vertexBuffer);
            pass.setBindGroup(0, top.modelBg);
            pass.drawIndexed(top.mesh.nIndis);
        }
        pass.end();
        const commands = encoder.finish();
        this.device.queue.submit([commands]);
    }
}
//# sourceMappingURL=sample.js.map