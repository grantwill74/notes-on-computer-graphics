const vertsInShaderCode = /*wgsl*/ `
const vert_positions: array<vec4f, 3> = array(
    vec4f(-.75, -.75, 0, 1),
    vec4f( .75, -.75, 0, 1),
    vec4f(   0,  .75, 0, 1),
);

@vertex fn vs(@builtin(vertex_index) index: u32) -> @builtin(position) vec4f {
    return vert_positions[index];
}

@fragment fn fs() -> @location(0) vec4f {
    return vec4f(0.4, 0.8, 0.3, 1.0);
}
`;
export function renderSample02_vertsInShader(device, context) {
    const shaderMod = device.createShaderModule({
        code: vertsInShaderCode,
        label: "shader with vertices inside"
    });
    const pipeline = device.createRenderPipeline({
        layout: 'auto',
        vertex: {
            module: shaderMod,
        },
        fragment: {
            module: shaderMod,
            targets: [
                { format: context.getCurrentTexture().format, }
            ],
        },
    });
    const encoder = device.createCommandEncoder();
    const pass = encoder.beginRenderPass({
        label: "pass with verts in shader",
        colorAttachments: [
            {
                loadOp: "clear",
                storeOp: "store",
                view: context.getCurrentTexture(),
                clearValue: { r: .7, g: .8, b: .9, a: 1.0 },
            }
        ]
    });
    pass.setViewport(0, 0, context.canvas.width, context.canvas.height, 0, 1);
    pass.setPipeline(pipeline);
    pass.draw(3);
    pass.end();
    const commands = encoder.finish();
    device.queue.submit([commands]);
}
//# sourceMappingURL=sample.js.map