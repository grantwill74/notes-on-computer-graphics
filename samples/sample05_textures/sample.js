const shaderCode = /*wgsl*/ `
    @group(0) @binding(0)
    var tex: texture_2d<f32>;

    @group(0) @binding(1)
    var samp: sampler;

    @group(1) @binding(0)
    var<uniform> offset: vec2f;

    struct VertexOutput {
        @builtin(position) pos: vec4f,
        @location(0) uvs: vec2f,
    };

    @vertex fn vs(
        @location(0) position: vec2f, 
        @location(1) uvs: vec2f,
    ) -> VertexOutput {
        var vo: VertexOutput;
        vo.pos = vec4f(position + offset, 0, 1);
        vo.uvs = uvs;
        return vo;
    }

    @fragment fn fs(vo: VertexOutput) -> @location(0) vec4f {
        return textureSample(tex, samp, vo.uvs);   
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
    const bindGroup0layout = device.createBindGroupLayout({
        entries: [
            {
                binding: 0,
                visibility: GPUShaderStage.FRAGMENT,
                texture: {}
            },
            {
                binding: 1,
                visibility: GPUShaderStage.FRAGMENT,
                sampler: {}
            }
        ]
    });
    const bindGroup1layout = device.createBindGroupLayout({
        entries: [
            {
                binding: 0,
                visibility: GPUShaderStage.VERTEX,
                buffer: {}
            }
        ]
    });
    const pipeline = device.createRenderPipeline({
        layout: device.createPipelineLayout({
            bindGroupLayouts: [
                bindGroup0layout,
                bindGroup1layout,
            ]
        }),
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
                { format: (context.getCurrentTexture().format + '-srgb')
                }
            ]
        }
    });
    return pipeline;
}
export function initSample05Verts(device) {
    /*
        // one triangle is grainy version
        const verts = new Float32Array([
        //     x     y      u   v
            -.75, -.75,     .75,  1,  // bottom left
             .75, -.75,     1,  1,  // bottom right
             .75,  .75,     1,  .75,  // top right
    
             .75,  .75,     1,  0,  // top right
            -.75,  .75,     0,  0,  // top left
            -.75, -.75,     0,  1,  // bottom left
        ]);
    */
    /*
        // repeating version
        const verts = new Float32Array([
            -.75, -.75,     0,  4,  // bottom left
             .75, -.75,     4,  4,  // bottom right
             .75,  .75,     4,  0,  // top right
    
             .75,  .75,     4,  0,  // top right
            -.75,  .75,     0,  0,  // top left
            -.75, -.75,     0,  4,  // bottom left
        ])
    */
    ///*
    // normal version
    const verts = new Float32Array([
        //     x     y      u   v
        -.75, -.75, 0, 1, // bottom left
        .75, -.75, 1, 1, // bottom right
        .75, .75, 1, 0, // top right
        .75, .75, 1, 0, // top right
        -.75, .75, 0, 0, // top left
        -.75, -.75, 0, 1, // bottom left
    ]);
    //*/
    /*
        // full screen version
        const verts = new Float32Array([
            -1, -1, 0, 1,
             1, -1, 1, 1,
             1,  1, 1, 0,
             1,  1, 1, 0,
            -1,  1, 0, 0,
            -1, -1, 0, 1,
        ]);
    
    
    */
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
    const bg = device.createBindGroup({
        layout: bgLayout,
        entries: [
            {
                binding: 0,
                resource: tex.createView(),
            },
            {
                binding: 1,
                resource: samp
            }
        ]
    });
    return bg;
}
export function initSample05OffsetBg(device, pipeline, offset) {
    // note, we could also take in the buffer as a parameter.
    // this would allow us to overwrite the data in the buffer without making
    // a new bind group. this is a good idea if it's expected to change every
    // frame.
    const [offx, offy] = offset;
    const bufData = new Float32Array([offx, offy]);
    const buf = device.createBuffer({
        size: bufData.byteLength,
        usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.UNIFORM,
        label: "uniform offset buffer",
        mappedAtCreation: true
    });
    (new Float32Array(buf.getMappedRange())).set(bufData);
    buf.unmap();
    const bg = device.createBindGroup({
        layout: pipeline.getBindGroupLayout(1),
        entries: [{
                binding: 0,
                resource: buf,
            }]
    });
    return bg;
}
export function renderSample05(device, context, pipeline, vertBuf, texBg, offsetBg) {
    const encoder = device.createCommandEncoder();
    const pass = encoder.beginRenderPass({
        colorAttachments: [{
                loadOp: 'clear',
                storeOp: 'store',
                view: context.getCurrentTexture().createView({
                    format: (context.getCurrentTexture().format + '-srgb')
                }),
                clearValue: { r: 0.7, g: 0.8, b: 0.9, a: 1 },
            }]
    });
    pass.setViewport(0, 0, context.canvas.width, context.canvas.height, 0, 1);
    pass.setPipeline(pipeline);
    pass.setVertexBuffer(0, vertBuf);
    pass.setBindGroup(0, texBg);
    pass.setBindGroup(1, offsetBg);
    pass.draw(6);
    pass.end();
    const commands = encoder.finish();
    device.queue.submit([commands]);
}
export async function loadTexture(device, url) {
    const response = await fetch(url);
    const blob = await response.blob();
    const bitmap = await createImageBitmap(blob);
    const tex = device.createTexture({
        format: "rgba8unorm-srgb",
        size: { width: bitmap.width, height: bitmap.height, depthOrArrayLayers: 1 },
        usage: GPUTextureUsage.RENDER_ATTACHMENT |
            GPUTextureUsage.COPY_DST |
            GPUTextureUsage.TEXTURE_BINDING,
        dimension: '2d',
        label: url.toString(),
    });
    device.queue.copyExternalImageToTexture({ source: bitmap }, { texture: tex, colorSpace: "srgb" }, { width: bitmap.width, height: bitmap.height, depthOrArrayLayers: 1 });
    return tex;
}
//# sourceMappingURL=sample.js.map