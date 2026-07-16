const shaderCode = /*wgsl*/ `
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
import { mat4, vec3 } from "gl-matrix";
const TAU = Math.PI * 2;
const TURNS_PER_SEC = 0.25;
export class Sample08 {
    device;
    context;
    pipeline;
    matBuf1;
    matBuf2;
    matBufViewProj;
    vertBuf;
    textureFormat;
    depthBuffer;
    bindGroup1;
    bindGroup2;
    bgCamera;
    rotationTurns;
    lastRenderTime;
    constructor(device, context) {
        this.device = device;
        this.context = context;
        this.rotationTurns = 0;
        this.textureFormat = (context.getCurrentTexture().format + '-srgb');
        this.lastRenderTime = performance.now(); // pretend we just rendered
        const shaderMod = device.createShaderModule({ code: shaderCode });
        const bgLayout = device.createBindGroupLayout({
            entries: [{
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {}
                }]
        });
        // we need a new layout for the view and projection matrix
        const viewProjLayout = device.createBindGroupLayout({
            entries: [{
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {}
                }]
        });
        // note, it still only has one entry at binding 0
        // it doesn't conflict.
        // the other matrix will be @group(0) @binding(0)
        // this one will be @group(1) @binding(0)
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
        // mat4.rotateY(stationary, stationary, .05* TAU);
        mat4.translate(stationary, stationary, vec3.fromValues(5, 0, 0));
        mat4.scale(stationary, stationary, vec3.fromValues(1, 1, 1));
        //mat4.rotateX(stationary, stationary, .05 * TAU);
        mat4.rotateY(stationary, stationary, .15 * TAU);
        (new Float32Array(this.matBuf2.getMappedRange())).set(stationary);
        this.matBuf2.unmap();
        const vertStride = 3 * 4 + 3 * 4;
        const vertData = new Float32Array([
            -1, -1, 1, 1, 0, 0,
            1, -1, 1, 1, 0, 0,
            1, 1, 1, 1, 0, 0,
            -1, -1, 1, 1, 0, 0,
            1, 1, 1, 1, 0, 0,
            -1, 1, 1, 1, 0, 0,
            1, 1, 1, 0, 1, 0,
            1, -1, 1, 0, 1, 0,
            1, -1, -1, 0, 1, 0,
            1, -1, -1, 0, 1, 0,
            1, 1, -1, 0, 1, 0,
            1, 1, 1, 0, 1, 0,
            -1, 1, -1, 0, 0, 1,
            1, 1, -1, 0, 0, 1,
            1, -1, -1, 0, 0, 1,
            1, -1, -1, 0, 0, 1,
            -1, -1, -1, 0, 0, 1,
            -1, 1, -1, 0, 0, 1,
            -1, -1, -1, 1, 1, 0,
            -1, -1, 1, 1, 1, 0,
            -1, 1, 1, 1, 1, 0,
            -1, 1, 1, 1, 1, 0,
            -1, 1, -1, 1, 1, 0,
            -1, -1, -1, 1, 1, 0,
            -1, 1, 1, 1, 0, 1,
            1, 1, 1, 1, 0, 1,
            1, 1, -1, 1, 0, 1,
            -1, 1, 1, 1, 0, 1,
            1, 1, -1, 1, 0, 1,
            -1, 1, -1, 1, 0, 1,
            -1, -1, 1, 0, 1, 1,
            -1, -1, -1, 0, 1, 1,
            1, -1, -1, 0, 1, 1,
            1, -1, -1, 0, 1, 1,
            1, -1, 1, 0, 1, 1,
            -1, -1, 1, 0, 1, 1,
        ]);
        this.vertBuf = device.createBuffer({
            size: vertData.byteLength,
            usage: GPUBufferUsage.VERTEX,
            label: "vertex buffer",
            mappedAtCreation: true,
        });
        (new Float32Array(this.vertBuf.getMappedRange())).set(vertData);
        this.vertBuf.unmap();
        this.matBufViewProj = device.createBuffer({
            size: 16 * 4,
            usage: GPUBufferUsage.UNIFORM,
            label: "viewProj buffer",
            mappedAtCreation: true,
        });
        const viewProj = mat4.create();
        // the camera is now at the origin, facing Z-
        // apply projection:
        mat4.perspectiveZO(viewProj, 0.15 * TAU, context.canvas.width / context.canvas.height, 1, 128);
        const view = mat4.create();
        //mat4.lookAt(view,
        //    vec3.fromValues(0, 0, 0),
        //    vec3.fromValues(0, 0, -1),
        //    vec3.fromValues(0, 1, 0));
        // don't use invert when using look at, it does it for you.
        mat4.rotateY(view, view, -.25 * TAU);
        mat4.invert(view, view);
        // viewProj is proj * view
        mat4.mul(viewProj, viewProj, view);
        (new Float32Array(this.matBufViewProj.getMappedRange())).set(viewProj);
        this.matBufViewProj.unmap();
        this.pipeline = device.createRenderPipeline({
            layout: device.createPipelineLayout({
                bindGroupLayouts: [bgLayout, viewProjLayout],
            }),
            vertex: {
                module: shaderMod,
                buffers: [{
                        arrayStride: vertStride,
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
            entries: [{ binding: 0, resource: this.matBuf2 }],
            layout: bgLayout
        });
        this.bgCamera = device.createBindGroup({
            entries: [{ binding: 0, resource: this.matBufViewProj }],
            layout: viewProjLayout
        });
    }
    // send new matrix data to overwrite what was there before
    update(dt) {
        const model = mat4.create();
        mat4.translate(model, model, vec3.fromValues(0, 0, -10));
        mat4.rotateX(model, model, .05 * TAU);
        mat4.rotateY(model, model, this.rotationTurns * TAU);
        this.rotationTurns += dt * TURNS_PER_SEC;
        this.rotationTurns %= 1; // wrap around once we hit 1 turn
        this.device.queue.writeBuffer(this.matBuf1, 0, new Float32Array(model));
    }
    render(now) {
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
                    clearValue: { r: .7, g: .8, b: .9, a: 1 },
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
        pass.setViewport(0, 0, this.context.canvas.width, this.context.canvas.height, 0, 1);
        pass.setPipeline(this.pipeline);
        pass.setVertexBuffer(0, this.vertBuf);
        pass.setBindGroup(1, this.bgCamera);
        // notice that the camera bind group is the same for both spinning 
        // cubes, so we only have to set it once. This is the main benefit of 
        // splitting data into multiple bind groups.
        pass.setBindGroup(0, this.bindGroup1);
        //pass.draw(36);
        pass.setBindGroup(0, this.bindGroup2);
        pass.draw(36);
        pass.end();
        const commands = encoder.finish();
        this.device.queue.submit([commands]);
    }
    startRendering() {
        const renderAndQueue = (now) => {
            this.render(now);
            requestAnimationFrame(renderAndQueue);
        };
        renderAndQueue(performance.now());
    }
}
//# sourceMappingURL=sample.js.map