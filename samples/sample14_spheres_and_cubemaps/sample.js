const shaderCode = /*wgsl*/ `
    @group(1) @binding(0) var<uniform> model: mat4x4<f32>;
    @group(1) @binding(1) var tex: texture_2d<f32>;
    @group(1) @binding(2) var samp: sampler;
    
    @group(0) @binding(0) var<uniform> proj: mat4x4<f32>;

    const PI = radians(180.0);
    const TAU = radians(360.0);

    struct VertexOutput {
        @builtin(position) pos: vec4f,
        @location(0) uvs: vec2f,
    }
    

    // it's okay to have more than one @vertex, as long as we specify which
    // one is being used in the pipeline.
    @vertex fn sphere_vs(@location(0) pos: vec3f) -> VertexOutput {
        var vo: VertexOutput;
        vo.pos = proj * model * vec4f(pos, 1.0);

        let u = atan2(pos.x, -pos.z) / TAU;
        let v = asin(pos.y) / PI + 0.5;
        vo.uvs = vec2f(u, v);

        return vo;
    }

    @fragment fn fs(vo: VertexOutput) -> @location(0) vec4f {
        return textureSample(tex, samp, vo.uvs);
    }
`;
class Mesh {
    vertData;
    indices;
    // feel free to look into a feature called "parameter properties"
    // for an easier way to build these simple "bag of data" classes.
    // for now: I will write them the way we learned in class.
    constructor(vertData, indices) {
        this.vertData = vertData;
        this.indices = indices;
    }
}
const PI = Math.PI;
const TAU = 2 * PI;
export function genUvSphere(xzSubdivs, ySubdivs, topo) {
    const verts = [];
    const pointsPerHorizRing = xzSubdivs + 1;
    for (let ySubdiv = 0; ySubdiv < ySubdivs; ySubdiv++) {
        let angle = (0.5 - ySubdiv / (ySubdivs - 1)) * Math.PI;
        let y = Math.sin(angle);
        let r = Math.sqrt(1 - y * y);
        for (let xzPoint = 0; xzPoint < pointsPerHorizRing; xzPoint++) {
            let angle = (xzPoint / (pointsPerHorizRing - 1)) * TAU;
            let x = Math.cos(angle) * r;
            let z = -Math.sin(angle) * r;
            verts.push(x, y, z);
            console.log(x, y, z);
        }
        console.log();
    }
    const restart = 0xFFFFFFFF;
    const indis = [];
    let i = 0;
    for (let ySubdiv = 0; ySubdiv < ySubdivs - 1; ySubdiv++) {
        for (let xzPoint = 0; xzPoint < pointsPerHorizRing; xzPoint++) {
            if (topo == 'point-list') {
                indis.push(i);
                i++;
            }
            else if (topo == 'line-list') {
                indis.push(i, i + 1);
                indis.push(i + 1, i + pointsPerHorizRing);
                indis.push(i + pointsPerHorizRing, i);
                indis.push(i + pointsPerHorizRing + 1, i + pointsPerHorizRing);
                indis.push(i + pointsPerHorizRing, i + 1);
                indis.push(i + 1, i + pointsPerHorizRing + 1);
                i++;
            }
            else if (topo == 'line-strip') {
                indis.push(i, i + 1, i + pointsPerHorizRing, restart);
                indis.push(i + pointsPerHorizRing + 1, i + pointsPerHorizRing, i + 1, restart);
                i++;
            }
            else if (topo == 'triangle-list') {
                indis.push(i, i + 1, i + pointsPerHorizRing);
                indis.push(i + pointsPerHorizRing + 1, i + pointsPerHorizRing, i + 1);
                i++;
            }
            else if (topo == 'triangle-strip') {
                indis.push(i, i + 1, i + pointsPerHorizRing, i + pointsPerHorizRing + 1);
                i++;
            }
            else {
                throw new Error("unknown topology: " + topo);
            }
        }
        if (topo == 'triangle-strip') {
            indis.push(restart);
        }
        i++;
    }
    return new Mesh(verts, indis);
}
export function genCubeSphere() {
    throw new Error("unimplemented");
}
class LoadedMesh {
    verts;
    indis;
    nVerts;
    nIndis;
    constructor(device, mesh) {
        this.nVerts = Math.floor(mesh.vertData.length / 3);
        this.nIndis = mesh.indices.length;
        const verts = new Float32Array(mesh.vertData);
        const indis = new Uint32Array(mesh.indices);
        this.verts = device.createBuffer({
            size: verts.byteLength,
            usage: GPUBufferUsage.VERTEX,
            mappedAtCreation: true
        });
        (new Float32Array(this.verts.getMappedRange())).set(verts);
        this.verts.unmap();
        this.indis = device.createBuffer({
            size: indis.byteLength,
            usage: GPUBufferUsage.INDEX,
            mappedAtCreation: true
        });
        (new Float32Array(this.indis.getMappedRange())).set(indis);
        this.indis.unmap();
    }
}
import { mat4, vec3 } from 'gl-matrix';
const SPHERE_SUBDIVS = 10;
const FOVY = TAU / 8;
export class Sample14 {
    device;
    context;
    sphereMap;
    // cubeMap: GPUTexture;
    uvSphere;
    // cubeSphereVerts: GPUTexture;
    sphereMapPipeline;
    format;
    passBgLayout;
    modelBgLayout;
    passBg;
    sphereModelBg;
    sphereModelMatBuf;
    projBuf;
    projMat = mat4.create();
    sphereModelMat = mat4.create();
    sphereSampler;
    constructor(device, context, sphereMap) {
        this.device = device;
        this.context = context;
        this.sphereMap = sphereMap;
        this.format = (context.getCurrentTexture().format + '-srgb');
        const uvMesh = genUvSphere(SPHERE_SUBDIVS, SPHERE_SUBDIVS, 'triangle-list');
        this.uvSphere = new LoadedMesh(device, uvMesh);
        const shaderMod = device.createShaderModule({ code: shaderCode });
        this.passBgLayout = device.createBindGroupLayout({
            entries: [{
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {}
                }]
        });
        this.modelBgLayout = device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {}
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {}
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: {}
                }
            ]
        });
        const pipelineLayout = device.createPipelineLayout({
            bindGroupLayouts: [this.passBgLayout, this.modelBgLayout]
        });
        const aspectr = context.canvas.width / context.canvas.height;
        mat4.perspectiveZO(this.projMat, FOVY, aspectr, 0.5, 10);
        this.projBuf = device.createBuffer({
            size: 16 * 4,
            usage: GPUBufferUsage.UNIFORM,
            label: "projection buffer",
            mappedAtCreation: true
        });
        (new Float32Array(this.projBuf.getMappedRange()).set(this.projMat));
        this.projBuf.unmap();
        this.passBg = device.createBindGroup({
            layout: this.passBgLayout,
            entries: [{
                    binding: 0,
                    resource: this.projBuf
                }]
        });
        mat4.translate(this.sphereModelMat, this.sphereModelMat, [0, 0, -4]);
        this.sphereModelMatBuf = device.createBuffer({
            size: 16 * 4,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
            label: "sphere mapped model buffer",
            mappedAtCreation: true
        });
        (new Float32Array(this.sphereModelMatBuf.getMappedRange()).set(this.sphereModelMat));
        this.sphereModelMatBuf.unmap();
        this.sphereSampler = device.createSampler({
            addressModeU: 'clamp-to-edge',
            addressModeV: 'clamp-to-edge',
            label: 'sphere map sampler',
            magFilter: 'linear',
            minFilter: 'linear',
        });
        this.sphereModelBg = device.createBindGroup({
            layout: this.modelBgLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.sphereModelMatBuf
                },
                {
                    binding: 1,
                    resource: this.sphereMap
                },
                {
                    binding: 2,
                    resource: this.sphereSampler
                }
            ]
        });
        // this time, our two pipelines share a lot of description, so we're 
        // factoring out some of it
        const bufferLayout = [{
                arrayStride: 3 * 4,
                attributes: [{
                        format: 'float32x3',
                        offset: 0,
                        shaderLocation: 0,
                    }]
            }];
        const fragmentState = {
            module: shaderMod,
            targets: [{
                    format: this.format,
                }]
        };
        const primitiveState = {
            cullMode: 'back',
            frontFace: 'ccw',
            topology: 'point-list',
            // topology: 'triangle-strip',
            // stripIndexFormat: 'uint32',
        };
        this.sphereMapPipeline = device.createRenderPipeline({
            layout: pipelineLayout,
            vertex: {
                module: shaderMod,
                entryPoint: 'sphere_vs', // we have two entry points now. one for sphere mapping, one for cube mapping.
                buffers: bufferLayout
            },
            fragment: fragmentState,
            label: "sphere map pipeline",
            primitive: primitiveState
        });
    }
    update() {
    }
    render() {
        const d = this.device;
        const c = this.context;
        const encoder = d.createCommandEncoder();
        const pass = encoder.beginRenderPass({
            colorAttachments: [{
                    loadOp: 'clear',
                    storeOp: 'store',
                    view: c.getCurrentTexture().createView({
                        format: this.format,
                    }),
                    clearValue: { r: .7, g: .8, b: .9, a: 1.0 },
                }]
        });
        pass.setPipeline(this.sphereMapPipeline);
        pass.setViewport(0, 0, c.canvas.width, c.canvas.height, 0, 1);
        pass.setBindGroup(0, this.passBg);
        pass.setBindGroup(1, this.sphereModelBg);
        pass.setVertexBuffer(0, this.uvSphere.verts);
        pass.setIndexBuffer(this.uvSphere.indis, 'uint32');
        pass.drawIndexed(this.uvSphere.nIndis);
        pass.end();
        const commands = encoder.finish();
        d.queue.submit([commands]);
    }
}
//# sourceMappingURL=sample.js.map