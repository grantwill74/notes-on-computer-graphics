const shaderCode = /*wgsl*/ `
@group(0) @binding(1) var<uniform> color: vec3f;
@group(0) @binding(0) var<uniform> model: mat4x4<f32>;

struct VertexOutput {
    @builtin(position) pos: vec4f,
    @location(0) color: vec4f,
};

@vertex fn vs(@location(0) pos: vec3f) ->  VertexOutput {
    var vo: VertexOutput;
    vo.pos = model * vec4(pos, 1);
    vo.color = vec4(color, 1);
    return vo;
}

@fragment fn fs(vo: VertexOutput) -> @location(0) vec4f {
    return vo.color;
}
`;
import { mat4, vec3 } from "gl-matrix";
const TAU = 2 * Math.PI;
export function renderSample06(device, context) {
    const shaderMod = device.createShaderModule({ code: shaderCode });
    const vertData = new Float32Array([
        -.5, -.5, 0,
        0, .5, 0,
        .5, -.5, 0,
    ]);
    const vertBuf = device.createBuffer({
        size: vertData.byteLength,
        usage: GPUBufferUsage.VERTEX,
        mappedAtCreation: true,
        label: "vert buf"
    });
    (new Float32Array(vertBuf.getMappedRange())).set(vertData);
    vertBuf.unmap();
    const bgLayout = device.createBindGroupLayout({
        entries: [
            {
                binding: 0,
                buffer: {},
                visibility: GPUShaderStage.VERTEX,
            },
            {
                binding: 1,
                buffer: {},
                visibility: GPUShaderStage.VERTEX,
            },
        ],
    });
    const matIdentity = mat4.create();
    const matRotate = mat4.create();
    const matScale = mat4.create();
    const matTranslate = mat4.create();
    mat4.rotateZ(matRotate, matIdentity, .1 * TAU);
    mat4.scale(matScale, matIdentity, vec3.fromValues(2, .5, 1));
    mat4.translate(matTranslate, matIdentity, vec3.fromValues(.4, -.4, 0));
    // define 4 buffers, one for each matrix
    const matrices = {
        'identity matrix': matIdentity,
        'rotation matrix': matRotate,
        'scaling matrix': matScale,
        'translation matrix': matTranslate,
    };
    const matrixBuffers = [];
    // add "ES2025" to your "lib" array in `tsconfig.json` to get Object.entries
    // it returns an iterator over all the key-value pairs in an object
    for (let [name, matrix] of Object.entries(matrices)) {
        const buf = device.createBuffer({
            size: 16 * 4,
            usage: GPUBufferUsage.UNIFORM,
            label: name,
            mappedAtCreation: true
        });
        (new Float32Array(buf.getMappedRange())).set(matrix);
        buf.unmap();
        matrixBuffers.push(buf);
    }
    // I put all 4 colors into one array to demonstrate how to do it.
    const colorData = new Float32Array([
        1, 0, 0, 1, // red
        0, 1, 0, 1, // green
        0, 0, 1, 1, // blue
        0, 1, 1, 1, // cyan
    ]);
    // it's possible to use one buffer, too, but the values have to be super
    // spread out (minimum alignment is 256 bytes) so it's kind of a pain.
    // instead, let's make 4 buffers, one for each vector. They will all pull
    // from different offsets in colorData.
    const colorBufs = [];
    for (let i = 0; i < 4; i++) {
        const colorBuf = device.createBuffer({
            size: 4 * 4,
            usage: GPUBufferUsage.UNIFORM,
            label: "color buffer",
            mappedAtCreation: true,
        });
        // we use slice here to cut up a portion of the color Data.
        // we go by 4 elements for each color
        (new Float32Array(colorBuf.getMappedRange())).set(colorData.slice(4 * i, 4 * i + 4));
        colorBuf.unmap();
        colorBufs.push(colorBuf);
    }
    // we now have to make 4 bind groups, one for each triangle we want to 
    // draw. Each one will get a different matrix, and will point into a 
    // different place in the color buffer.
    const bindGroups = [];
    for (let i = 0; i < 4; i++) {
        // link the matrix to the spot in the color buffer.
        const bg = device.createBindGroup({
            layout: bgLayout,
            entries: [
                {
                    binding: 0,
                    resource: matrixBuffers[i],
                },
                {
                    binding: 1,
                    resource: colorBufs[i]
                }
            ],
        });
        bindGroups.push(bg);
    }
    const srgbFormat = (context.getCurrentTexture().format + '-srgb');
    const pipeline = device.createRenderPipeline({
        layout: device.createPipelineLayout({
            bindGroupLayouts: [bgLayout],
        }),
        vertex: {
            module: shaderMod,
            buffers: [
                {
                    arrayStride: 3 * 4,
                    attributes: [{
                            format: 'float32x3',
                            offset: 0,
                            shaderLocation: 0,
                        }]
                }
            ]
        },
        fragment: {
            module: shaderMod,
            targets: [{ format: srgbFormat }]
        },
    });
    const encoder = device.createCommandEncoder();
    const pass = encoder.beginRenderPass({
        colorAttachments: [{
                loadOp: 'clear',
                storeOp: 'store',
                view: context.getCurrentTexture().createView({
                    format: srgbFormat
                }),
                clearValue: { r: .7, g: .8, b: .9, a: 1 }
            }]
    });
    const hw = context.canvas.width / 2;
    const hh = context.canvas.height / 2;
    pass.setPipeline(pipeline);
    pass.setViewport(0, 0, hw, hh, 0, 1);
    pass.setVertexBuffer(0, vertBuf);
    pass.setBindGroup(0, bindGroups[0]);
    pass.draw(3);
    pass.setBindGroup(0, bindGroups[1]); // now load the next color and matrix
    pass.setViewport(hw, 0, hw, hh, 0, 1); // draw in the top right quadrant
    pass.draw(3);
    pass.setBindGroup(0, bindGroups[2]);
    pass.setViewport(0, hh, hw, hh, 0, 1);
    pass.draw(3);
    pass.setBindGroup(0, bindGroups[3]);
    pass.setViewport(hw, hh, hw, hh, 0, 1);
    pass.draw(3);
    pass.end();
    const commands = encoder.finish();
    device.queue.submit([commands]);
}
//# sourceMappingURL=sample.js.map