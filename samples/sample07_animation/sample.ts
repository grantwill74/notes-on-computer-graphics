const shaderCode = /*wgsl*/`
@group(0) @binding(0)
var<uniform> model: mat4x4<f32>;

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
    vo.pos = model * vec4f(pos, 1.0);
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

import { mat4, vec3 } from "gl-matrix";

const TAU = Math.PI * 2;
const TURNS_PER_SEC = 0.25;

export class Sample07 {
    device: GPUDevice;
    context: GPUCanvasContext;
    pipeline: GPURenderPipeline;
    matBuf1: GPUBuffer;
    matBuf2: GPUBuffer;
    vertBuf: GPUBuffer;
    textureFormat: GPUTextureFormat;
    depthBuffer: GPUTexture;
    bindGroup1: GPUBindGroup;
    bindGroup2: GPUBindGroup;

    rotationTurns: number;
    lastRenderTime: number;

    constructor(device: GPUDevice, context: GPUCanvasContext) {
        this.device = device;
        this.context = context;
        this.rotationTurns = 0;
        this.textureFormat = (context.getCurrentTexture().format + '-srgb') as
            GPUTextureFormat;
        this.lastRenderTime = performance.now(); // pretend we just rendered

        const shaderMod = device.createShaderModule({code: shaderCode});
        const bgLayout = device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {}
                }
            ]
        });

        this.matBuf1 = device.createBuffer({
            size: 16 * 4,
            // need copy dest in order to write the new matrix every frame
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
            label: "rotating matrix buffer",
            mappedAtCreation: false,
        });
        // notice: we're not mapping this one.
        // we're going to overwrite it once per frame, so there's no real
        // reason to write to it right now.

        this.matBuf2 = device.createBuffer({
            size: 16 * 4,
            usage: GPUBufferUsage.UNIFORM,
            label: "stationary matrix buffer",
            mappedAtCreation: true,
        });
        const stationary = mat4.create();
        mat4.translate(stationary, stationary, vec3.fromValues(.4, 0, .86));        
        mat4.scale(stationary, stationary, vec3.fromValues(0.4, 0.4, 0.4));
        mat4.rotateX(stationary, stationary, -.05 * TAU);
        mat4.rotateY(stationary, stationary, -.15 * TAU);
        (new Float32Array(this.matBuf2.getMappedRange())).set(stationary);
        this.matBuf2.unmap();
        
        const vertStride = 3 * 4 + 3 * 4;
        const vertData = new Float32Array([
            -.3, -.3, -.3,  1, 0, 0,
             .3, -.3, -.3,  1, 0, 0,
             .3,  .3, -.3,  1, 0, 0,
            -.3, -.3, -.3,  1, 0, 0,
             .3,  .3, -.3,  1, 0, 0,
            -.3,  .3, -.3,  1, 0, 0,

             .3,  .3, -.3,  0, 1, 0,
             .3, -.3, -.3,  0, 1, 0,
             .3, -.3,  .3,  0, 1, 0,
             .3, -.3,  .3,  0, 1, 0,
             .3,  .3,  .3,  0, 1, 0,
             .3,  .3, -.3,  0, 1, 0,

            -.3,  .3,  .3,  0, 0, 1,
             .3,  .3,  .3,  0, 0, 1,
             .3, -.3,  .3,  0, 0, 1,
             .3, -.3,  .3,  0, 0, 1,
            -.3, -.3,  .3,  0, 0, 1,
            -.3,  .3,  .3,  0, 0, 1,

            -.3, -.3,  .3,  1, 1, 0,
            -.3, -.3, -.3,  1, 1, 0,
            -.3,  .3, -.3,  1, 1, 0,
            -.3,  .3, -.3,  1, 1, 0,
            -.3,  .3,  .3,  1, 1, 0,
            -.3, -.3,  .3,  1, 1, 0,

            -.3,  .3, -.3,  1, 0, 1,
             .3,  .3, -.3,  1, 0, 1,
             .3,  .3,  .3,  1, 0, 1,
            -.3,  .3, -.3,  1, 0, 1,
             .3,  .3,  .3,  1, 0, 1,
            -.3,  .3,  .3,  1, 0, 1,

            -.3, -.3, -.3,  0, 1, 1,
            -.3, -.3,  .3,  0, 1, 1,
             .3, -.3,  .3,  0, 1, 1,
             .3, -.3,  .3,  0, 1, 1,
             .3, -.3, -.3,  0, 1, 1,
            -.3, -.3, -.3,  0, 1, 1,
        ]);
        this.vertBuf = device.createBuffer({
            size: vertData.byteLength,
            usage: GPUBufferUsage.VERTEX,
            label: "vertex buffer",
            mappedAtCreation: true,
        });
        (new Float32Array(this.vertBuf.getMappedRange())).set(vertData);
        this.vertBuf.unmap();
        // this one we are mapping, because we only have to write to it once.
        // might as well do it now.

        this.pipeline = device.createRenderPipeline({
            layout: device.createPipelineLayout({
                bindGroupLayouts: [bgLayout],
            }),
            vertex: {
                module: shaderMod,
                buffers: [{
                    arrayStride: vertStride,
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
                    format: this.textureFormat,
                }]
            },
            primitive: {
                cullMode: 'back',
                // cullMode: 'none',
                frontFace: 'ccw',
                topology: 'triangle-list',
            },
            // this is new, we need a depth buffer
            depthStencil: {
                format: 'depth24plus-stencil8',
                depthCompare: 'less-equal',
                depthWriteEnabled: true,
            },
        });

        // our depth buffer will be a texture.
        // for now, ignore the stencil buffer stuff.
        this.depthBuffer = device.createTexture({
            format: 'depth24plus-stencil8',
            size: {
                width: context.canvas.width,
                height: context.canvas.height,
                depthOrArrayLayers: 1
            },
            usage: GPUTextureUsage.RENDER_ATTACHMENT,
            label: 'depth buffer',
        });

        this.bindGroup1 = device.createBindGroup({
            entries: [
                {
                    binding: 0,
                    resource: this.matBuf1,
                }
            ],
            layout: bgLayout
        });

        this.bindGroup2 = device.createBindGroup({
            entries: [{binding: 0, resource: this.matBuf2}],
            layout: bgLayout
        });
    }

    // send new matrix data to overwrite what was there before
    update(dt: number): void {
        const model = mat4.create();
        mat4.translate(model, model, vec3.fromValues(0, 0, .5));
        mat4.rotateX(model, model, -.05 * TAU);
        mat4.rotateY(model, model, -this.rotationTurns * TAU);
        this.rotationTurns += dt * TURNS_PER_SEC;
        this.rotationTurns %= 1; // wrap around once we hit 1 turn

        this.device.queue.writeBuffer(this.matBuf1, 0, new Float32Array(model));
    }

    render(now: number): void {
        // `now` is in milliseconds. We take the delta and convert it to seconds
        const dt = (now - this.lastRenderTime) / 1000;
        this.lastRenderTime = now;

        this.update(dt);

        const encoder = this.device.createCommandEncoder();
        
        const pass = encoder.beginRenderPass({
            colorAttachments: [{
                loadOp: 'clear',
                storeOp: 'store',
                view: this.context.getCurrentTexture().createView({
                    format: this.textureFormat
                }),
                clearValue: {r: .7, g: .8, b: .9, a: 1},
            }],
            // this is new too. we need our pass to know that it will be 
            // using the depth buffer.
            depthStencilAttachment: {
                view: this.depthBuffer,
                depthClearValue: 1,
                depthLoadOp: "clear",
                depthStoreOp: "store",
                //depthReadOnly: true,
                stencilReadOnly: true,
            }
        });

        pass.setViewport(0, 0,
            this.context.canvas.width,
            this.context.canvas.height, 0, 1);
        pass.setPipeline(this.pipeline);
        pass.setVertexBuffer(0, this.vertBuf);
        pass.setBindGroup(0, this.bindGroup1);
        pass.draw(36);
        pass.setBindGroup(0, this.bindGroup2);
        pass.draw(36);
        pass.end();

        const commands = encoder.finish();
        this.device.queue.submit([commands]);
    }

    startRendering(): void {
        const renderAndQueue = (now: number) => {
            this.render(now);
            requestAnimationFrame(renderAndQueue);
        }
        renderAndQueue(performance.now());
    }
}
