const vertsInBufferCode = /*wgsl*/ `
    @vertex fn vs(@location(0) vertPos: vec3f) -> @builtin(position) vec4f {
        return vec4f(vertPos, 1.0); // expand the 3D coord to 4D
    }

    @fragment fn fs() -> @location(0) vec4f {
        return vec4f(0.4, 0.8, 0.3, 1.0);
    }
`;
export function createFloat32Buffer(device, data, usage, label = undefined) {
    const buf = device.createBuffer({
        size: data.byteLength,
        usage,
        mappedAtCreation: true,
    });
    if (label)
        buf.label = label;
    (new Float32Array(buf.getMappedRange())).set(data);
    buf.unmap();
    return buf;
}
export function renderSample03_vertsInBuffer(device, context) {
    const shaderMod = device.createShaderModule({
        code: vertsInBufferCode,
        label: "shader which gets its vertices from a buffer"
    });
    const vertData = new Float32Array([
        -.75, -.75, 0,
        .75, -.75, 0,
        0, .75, 0,
    ]);
    const stride = 4 * 3; // sizeof(float) * floats_per_vertex
    const vertBuf = device.createBuffer({
        size: vertData.byteLength,
        usage: GPUBufferUsage.VERTEX,
        label: "triangle vertex buffer",
        mappedAtCreation: true,
    });
    (new Float32Array(vertBuf.getMappedRange())).set(vertData);
    vertBuf.unmap();
    const pipeline = device.createRenderPipeline({
        layout: 'auto',
        vertex: {
            module: shaderMod,
            buffers: [
                {
                    arrayStride: stride,
                    attributes: [
                        {
                            format: "float32x3",
                            offset: 0,
                            shaderLocation: 0,
                        }
                    ]
                }
            ]
        },
        fragment: {
            module: shaderMod,
            targets: [
                { format: context.getCurrentTexture().format }
            ]
        },
        label: "pipeline which uses a vertex buffer"
    });
    const encoder = device.createCommandEncoder();
    const pass = encoder.beginRenderPass({
        colorAttachments: [
            {
                loadOp: 'clear',
                storeOp: 'store',
                view: context.getCurrentTexture(),
                clearValue: { r: .7, g: .8, b: .9, a: 1.0 },
            }
        ]
    });
    pass.setViewport(0, 0, context.canvas.width, context.canvas.height, 0, 1);
    pass.setPipeline(pipeline);
    pass.setVertexBuffer(0, vertBuf);
    pass.draw(3);
    pass.end();
    const commands = encoder.finish();
    device.queue.submit([commands]);
}
//# sourceMappingURL=sample.js.map