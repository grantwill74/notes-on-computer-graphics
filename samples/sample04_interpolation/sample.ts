const shaderCode = /*wgsl*/`
    const gamma: f32 = 2.2;
    const inv_gamma: f32 = 1.0 / gamma;

    struct VertexOutput {
        @builtin(position) pos: vec4f,
        @location(0) linear_color: vec3f,
    };

    @vertex fn vs(
        @location(0) pos: vec2f,
        @location(1) color: vec3f,
    ) -> VertexOutput 
    {
        var vo: VertexOutput;
        vo.pos = vec4f(pos, 0, 1);
        vo.linear_color = pow(color, vec3f(gamma)); 
        return vo;
    }

    @fragment fn fs(vo: VertexOutput) -> @location(0) vec4f {
        let perceptual_color = pow(vo.linear_color, vec3f(inv_gamma));
        return vec4f(perceptual_color, 1.0);
    }
`;

const stride = 2 * 4 + 3 * 4;
export function initSample04Vertices(
    device: GPUDevice,
): GPUBuffer
{
    const vertData = new Float32Array([
        -.75, -.75,     1, 0, 0,
         .75, -.75,     0, 1, 0,
           0,  .75,     0, 0, 1,
    ]);

    const buf = device.createBuffer({
        size: vertData.byteLength,
        usage: GPUBufferUsage.VERTEX,
        label: "triangle verts",
        mappedAtCreation: true,
    });
    (new Float32Array(buf.getMappedRange())).set(vertData);
    buf.unmap();

    return buf;
}

export function initSample04Pipeline(
    device: GPUDevice,
    context: GPUCanvasContext
): GPURenderPipeline
{
    const shaderMod = device.createShaderModule({code: shaderCode});

    const pipeline = device.createRenderPipeline({
        layout: 'auto',
        vertex: {
            module: shaderMod,
            buffers: [{
                arrayStride: stride,
                attributes: [ // there are 2!
                    { // position
                        format: "float32x2",
                        offset: 0,
                        shaderLocation: 0
                    },
                    { // color 
                        format: "float32x3",
                        offset: 2 * 4,
                        shaderLocation: 1,
                    },
                ]
            }]
        },
        fragment: {
            module: shaderMod,
            targets: [{
                format: context.getCurrentTexture().format,
            }]
        },
    });

    return pipeline;
}

export function renderSample04(
    device: GPUDevice,
    context: GPUCanvasContext,
    pipeline: GPURenderPipeline,
    vertBuf: GPUBuffer
): void
{
    const encoder = device.createCommandEncoder();
    const pass = encoder.beginRenderPass({
        colorAttachments: [{
            loadOp: 'clear',
            storeOp: 'store',
            view: context.getCurrentTexture(),
            clearValue: {r: .7, g: .8, b: .9, a: 1},
        }]
    });
    pass.setViewport(0, 0, context.canvas.width, context.canvas.height, 0, 1);
    pass.setVertexBuffer(0, vertBuf);
    pass.setPipeline(pipeline);
    pass.draw(3);
    pass.end();

    const commands = encoder.finish();
    device.queue.submit([commands]);
}
