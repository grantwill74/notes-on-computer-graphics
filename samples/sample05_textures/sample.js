const shaderCode = /*wgsl*/ `
    const gamma: f32 = 2.2;
    const inv_gamma: f32 = 1.0 / gamma;

    @group(0) @binding(0)
    var tex: texture_2d<f32>;

    @group(0) @binding(1)
    var samp: sampler;

    struct VertexOutput {
        @builtin(position) pos: vec4f,
        @location(0) uvs: vec2f,
    };

    @vertex fn vs(
        @location(0) position: vec2f, 
        @location(1) uvs: vec2f,
    ) -> VertexOutput {
        var vo: VertexOutput;
        vo.pos = vec4f(position, 0, 1);
        vo.uvs = uvs;
        return vo;
    }

    @fragment fn fs(vo: VertexOutput) -> @location(0) vec4f {
        let linear_tex_sample = textureSample(tex, samp, vo.uvs);
        return pow(linear_tex_sample, vec4f(inv_gamma));
    }
`;
export function genXorTexture(device, width = 256, height = 256) {
    const pitch = width * 4; // length of a row in bytes. 4 bytes per pixel.
    // a clamped array is just a Uint8Array that clamps the input numbers
    // to a range of [0, 255]. It is required for the ImageData constructor.
    const buf = new Uint8ClampedArray(pitch * height);
    for (let row = 0; row < height; row++) {
        for (let col = 0; col < width; col++) {
            const i = pitch * row + col * 4;
            buf[i] = buf[i + 1] = buf[i + 2] = row ^ col;
            buf[i + 3] = 255; // max alpha
        }
    }
    const tex = device.createTexture({
        // notice that we use the srgb format.
        // this is important, so that brightness values are considered
        // to be perceived brightness instead of linear brightness.
        format: "rgba8unorm-srgb",
        size: { width, height, depthOrArrayLayers: 1 },
        usage: GPUTextureUsage.TEXTURE_BINDING |
            GPUTextureUsage.RENDER_ATTACHMENT |
            GPUTextureUsage.COPY_DST,
        dimension: '2d',
        label: "xor texture"
    });
    const texData = new ImageData(buf, width, height, { colorSpace: "srgb", pixelFormat: "rgba-unorm8" });
    device.queue.copyExternalImageToTexture({ source: texData }, { texture: tex, colorSpace: "srgb" }, { width, height, depthOrArrayLayers: 1 });
    return tex;
}
export function initSample05Pipeline(device, context) {
    const shaderMod = device.createShaderModule({ code: shaderCode });
    const pipeline = device.createRenderPipeline({
        layout: 'auto',
        vertex: {
            module: shaderMod,
            buffers: [{
                    arrayStride: 2 * 4 + 2 * 4,
                    attributes: [
                        {
                            format: "float32x2",
                            offset: 0,
                            shaderLocation: 0,
                        },
                        {
                            format: 'float32x2',
                            offset: 2 * 4,
                            shaderLocation: 1,
                        }
                    ]
                }]
        },
        fragment: {
            module: shaderMod,
            targets: [
                { format: context.getCurrentTexture().format }
            ]
        }
    });
    return pipeline;
}
export function initSample05Verts(device) {
    const verts = new Float32Array([
        //     x     y      u   v
        -.75, -.75, 0, 1, // bottom left
        .75, -.75, 1, 1, // bottom right
        .75, .75, 1, 0, // top right
        .75, .75, 1, 0, // top right
        -.75, .75, 0, 0, // top left
        -.75, -.75, 0, 1, // bottom left
    ]);
    const buf = device.createBuffer({
        size: verts.byteLength,
        usage: GPUBufferUsage.VERTEX,
        label: "vert data",
        mappedAtCreation: true,
    });
    (new Float32Array(buf.getMappedRange())).set(verts);
    buf.unmap();
    return buf;
}
export function createTextureAndSamplerBindGroup(device, pipeline, tex, samp) {
    const bgLayout = pipeline.getBindGroupLayout(0);
    /*
    const bgLayout = device.createBindGroupLayout({
        entries: [
            { // texture
                binding: 0,
                visibility: GPUShaderStage.FRAGMENT,
                texture: {}
            },
            { // sampler
                binding: 1,
                visibility: GPUShaderStage.FRAGMENT,
                sampler: {}
            },
        ]
    });
    */
    const bg = device.createBindGroup({
        layout: bgLayout,
        entries: [
            {
                binding: 0,
                resource: tex,
            },
            {
                binding: 1,
                resource: samp
            }
        ]
    });
    return bg;
}
export function renderSample05(device, context, pipeline, vertBuf, bg) {
    const encoder = device.createCommandEncoder();
    const pass = encoder.beginRenderPass({
        colorAttachments: [{
                loadOp: 'clear',
                storeOp: 'store',
                view: context.getCurrentTexture(),
                clearValue: { r: 0.7, g: 0.8, b: 0.9, a: 1 },
            }]
    });
    pass.setViewport(0, 0, context.canvas.width, context.canvas.height, 0, 1);
    pass.setPipeline(pipeline);
    pass.setVertexBuffer(0, vertBuf);
    pass.setBindGroup(0, bg);
    pass.draw(6);
    pass.end();
    const commands = encoder.finish();
    device.queue.submit([commands]);
}
/*
export async function loadTexture(
    device: GPUDevice,
    url: URL,
): Promise<GPUTexture>
{

    const tex = device.createTexture({

    });
}
*/
//# sourceMappingURL=sample.js.map