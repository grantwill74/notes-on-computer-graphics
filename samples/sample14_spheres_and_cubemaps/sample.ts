const sphereShader = /*wgsl*/`
    @group(1) @binding(0) var<uniform> model: mat4x4<f32>;
    @group(1) @binding(1) var tex: texture_2d<f32>;
    @group(1) @binding(2) var samp: sampler;
    
    @group(0) @binding(0) var<uniform> proj: mat4x4<f32>;

    struct VertexOutput {
        @builtin(position) pos: vec4f,
        @location(0) uvs: vec2f,
    }

    @vertex fn sphere_vs(
        @location(0) pos: vec3f,
        @location(1) uvs: vec2f
    ) -> VertexOutput {
        var vo: VertexOutput;
        vo.pos = proj * model * vec4f(pos, 1.0);
        vo.uvs = uvs;

        return vo;
    }

    @fragment fn sphere_fs(vo: VertexOutput) -> @location(0) vec4f {
        // return vec4(1, 0, 0, 1);
        return textureSample(tex, samp, vo.uvs);
    }
`;

const cubeShader = /*wgsl*/`
    @group(1) @binding(0) var<uniform> model: mat4x4<f32>;
    @group(1) @binding(1) var tex: texture_cube<f32>;
    @group(1) @binding(2) var samp: sampler;
    
    @group(0) @binding(0) var<uniform> proj: mat4x4<f32>;

    struct VertexOutput {
        @builtin(position) pos: vec4f,
        @location(0) model_pos: vec3f,
    }

    @vertex fn cube_vs(@location(0) pos: vec3f) -> VertexOutput {
        var vo: VertexOutput;
        vo.pos = proj * model * vec4f(pos, 1.0);
        vo.model_pos = pos;
        return vo;
    }

    @fragment fn cube_fs(vo: VertexOutput) -> @location(0) vec4f {
        // return vec4(1, 0, 0, 1);

        // we're using the position as a UV lookup: the direction it points 
        // will be used to sample the cube-map texture.
        return textureSample(tex, samp, normalize(vo.model_pos));
    }
`;

import { mat4, vec3 } from 'gl-matrix'

class Mesh {
    vertData: number[];
    indices: number[];

    // feel free to look into a feature called "parameter properties"
    // for an easier way to build these simple "bag of data" classes.
    // for now: I will write them the way we learned in class.
    constructor(
        vertData: number[],
        indices: number[]
    ) {
        this.vertData = vertData;
        this.indices = indices;
    }
}

const PI = Math.PI;
const TAU = 2 * PI;
const RESTART = 0xFFFFFFFF;

export function genUvSphere(
    xzSubdivs: number,
    ySubdivs: number,
    topo: GPUPrimitiveTopology
): Mesh {
    const verts: number[] = [];

    const nRings = ySubdivs + 1;
    // we need a duplicate vertex at the end that overlaps the start of each ring
    // because it will have a different U coordinate.
    const pointsPerHorizRing = xzSubdivs + 1;
    
    for (let ring = 0; ring < nRings; ring++) {
        let angle = (0.5 - ring / ySubdivs) * Math.PI;
        let y = Math.sin(angle);
        let r = Math.sqrt(1 - y*y);
        let v = ring / ySubdivs;

        for (let xzPoint = 0; xzPoint < pointsPerHorizRing; xzPoint++) {
            let u = xzPoint / xzSubdivs;
            let angle = u * TAU;
            console.log(angle);
            // the last point must be 2*pi in order for the generate U coordinate
            // to be 1 there instead of wrapping around.

            let x = Math.cos(angle) * r;
            let z = -Math.sin(angle) * r;
            
            verts.push(x, y, z, u, v);
        }
    }
    
    const indis: number[] = [];
    if (topo == 'point-list') {
        for (let i = 0; i < verts.length / 3; i++) {
            indis.push(i);
        }
    }
    else if (topo == 'line-list') {
        for (let ring = 0; ring < ySubdivs; ring++) {
            for (let xzPoint = 0; xzPoint < xzSubdivs; xzPoint++) {
                let i = ring * pointsPerHorizRing + xzPoint;
                let j = i + 1;
                indis.push(i, j, j, i + pointsPerHorizRing, i + pointsPerHorizRing, i);
            }
        }
    }
    else if (topo == 'triangle-list') {
        for (let ring = 0; ring < ySubdivs; ring++) {
            for (let xzPoint = 0; xzPoint < xzSubdivs; xzPoint++) {
                let i = ring * pointsPerHorizRing + xzPoint;
                let j = i + 1
                indis.push(j, i, i + pointsPerHorizRing);
                indis.push(j, i + pointsPerHorizRing, j + pointsPerHorizRing);
            }
        }
    } // could you implement a triangle strip for this one?
    else {
        throw new Error("unsupported topology: " + topo);
    }

    return new Mesh(verts, indis);
}

// no need for UVs in this one
// I only generate a triangle strip for this one. it's the easiest.
export function genCubeSphere(nFaceSubdivs: number, topo: GPUPrimitiveTopology): Mesh {
    const verts: number[] = [];
    const indis: number[] = [];

    const spanVerts = nFaceSubdivs + 1;
    // front face
    for (let row = 0; row < spanVerts; row++) {
        for (let col = 0; col < spanVerts; col++) {
            const y = 2 * row / nFaceSubdivs - 1;
            const x = 2 * col / nFaceSubdivs - 1;
            const l = Math.sqrt(x * x + y * y + 1);
            verts.push(x / l, y / l, 1 / l);
        }
    }
    // back face
    for (let row = 0; row < spanVerts; row++) {
        for (let col = spanVerts - 1; col >= 0; col--) {
            const y = 2 * row / nFaceSubdivs - 1;
            const x = 2 * col / nFaceSubdivs - 1;
            const l = Math.sqrt(x * x + y * y + 1);
            verts.push(x / l, y / l, -1 / l);
        }
    }
    // right face
    for (let row = 0; row < spanVerts; row++) {
        for (let col = spanVerts - 1; col >= 0; col--) {
            const y = 2 * row / nFaceSubdivs - 1;
            const z = 2 * col / nFaceSubdivs - 1;
            const l = Math.sqrt(z * z + y * y + 1);
            verts.push(1 / l, y / l, z / l);
        }
    }
    // left face
    for (let row = 0; row < spanVerts; row++) {
        for (let col = 0; col < spanVerts; col++) {
            const y = 2 * row / nFaceSubdivs - 1;
            const z = 2 * col / nFaceSubdivs - 1;
            const l = Math.sqrt(z * z + y * y + 1);
            verts.push(-1 / l, y / l, z / l);
        }
    }
    // top face
    for (let row = 0; row < spanVerts; row++) {
        for (let col = 0; col < spanVerts; col++) {
            const z = 2 * row / nFaceSubdivs - 1;
            const x = 2 * col / nFaceSubdivs - 1;
            const l = Math.sqrt(z * z + x * x + 1);
            verts.push(x / l, 1 / l, -z / l);
        }
    }
    // bottom face
    for (let row = 0; row < spanVerts; row++) {
        for (let col = 0; col < spanVerts; col++) {
            const z = 2 * row / nFaceSubdivs - 1;
            const x = 2 * col / nFaceSubdivs - 1;
            const l = Math.sqrt(z * z + x * x + 1);
            verts.push(x / l, -1 / l, z / l);
        }
    }
    
    const faceVerts = spanVerts * spanVerts;
    const faces = 6;
    if (topo == 'triangle-strip') {
        for (let face = 0; face < faces; face++) {
            for (let row = 0; row < nFaceSubdivs; row++) {
                for (let col = 0; col < spanVerts; col++) {
                    const i = face * faceVerts + row * spanVerts + col; 
                    indis.push(i + spanVerts, i);
                }
                indis.push(RESTART);
            }
        }
    }
    else if (topo == 'line-strip') {
        for (let face = 0; face < faces; face++) {
            for (let row = 0; row < nFaceSubdivs; row++) {
                for (let col = 0; col < nFaceSubdivs; col++) {
                    const i = face * faceVerts + row * spanVerts + col;
                    // not the most efficient topology, but for demo only
                    indis.push(i, i + 1, i + spanVerts + 1, i + spanVerts, i + 1);
                    indis.push(RESTART);
                }
            }
        }
    }
    else {
        throw new Error("unsupported topology");
    }

    return new Mesh(verts, indis);
}

/// load from a single texture that contains all 6 faces
// uvs will be a list of 6 UV coordinates
export async function loadCubemapUnfurled(
    device: GPUDevice,
    url: URL,
    uvs: [number, number][],
    faceDim: [number, number], // width and height of face in UV coordinates
): Promise<GPUTexture> 
{
    console.assert(uvs.length == 6, "expected 6 pairs of UV coordinates, each corresponding to the top left of one face.");
    
    const request = await fetch(url);
    const blob = await request.blob();
    const data = await createImageBitmap(blob);

    const faceW = faceDim[0] * data.width;
    const faceH = faceDim[1] * data.height;

    const tex = device.createTexture({
        format: 'rgba8unorm-srgb',
        size: {width: faceW, height: faceH, depthOrArrayLayers: 6},
        usage: GPUTextureUsage.TEXTURE_BINDING |
            GPUTextureUsage.COPY_DST |
            GPUTextureUsage.RENDER_ATTACHMENT,
        dimension: '2d',
        label: '' + url
    });

    for (let face = 0; face < 6; face++) {
        const [u, v] = uvs[face] as [number, number];
        const x = Math.round(u * data.width);
        const y = Math.round(v * data.height);
        device.queue.copyExternalImageToTexture(
            {source: data, origin: [x, y]},
            {texture: tex, colorSpace: 'srgb', origin: [0, 0, face]},
            [faceW, faceH, 1]
        );
    } 

    data.close();

    return tex;
}

class LoadedMesh {
    verts: GPUBuffer;
    indis: GPUBuffer;

    nIndis: number;

    constructor(device: GPUDevice, mesh: Mesh) {
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
        (new Uint32Array(this.indis.getMappedRange())).set(indis);
        this.indis.unmap();
    }
}


const SPHERE_SUBDIVS = 10;
const FOVY = TAU / 8;
const ROT_SPEED_TURNS = 1 / 16;
const ROT_PERIOD = 1 / ROT_SPEED_TURNS;
const SPHERE_MODEL_POS = [0, 0, -4];
const SPHERE_TOPO: GPUPrimitiveTopology = 'triangle-list'
const CUBE_TOPO: GPUPrimitiveTopology = 'triangle-strip'

export class Sample14 {
    device: GPUDevice;
    context: GPUCanvasContext;

    sphereMap: GPUTexture;
    cubeMap: GPUTexture;

    uvSphere: LoadedMesh;
    cubeSphere: LoadedMesh;

    sphereMapPipeline: GPURenderPipeline;
    cubeMapPipeline: GPURenderPipeline;
    
    format: GPUTextureFormat;

    passBg: GPUBindGroup;
    sphereModelBg: GPUBindGroup;
    cubeModelBg: GPUBindGroup;

    sphereModelMatBuf: GPUBuffer;
    projBuf: GPUBuffer;
    
    projMat: mat4 = mat4.create();
    sphereModelMat = mat4.create();
    sphereSampler: GPUSampler;
    cubeSampler: GPUSampler;

    constructor(
        device: GPUDevice,
        context: GPUCanvasContext,
        sphereMap: GPUTexture,
        cubeMap: GPUTexture,
    ) {
        this.device = device;
        this.context = context;
        this.sphereMap = sphereMap;
        this.cubeMap = cubeMap;

        this.format = (context.getCurrentTexture().format as string + '-srgb') as GPUTextureFormat

        const uvMesh = genUvSphere(SPHERE_SUBDIVS, SPHERE_SUBDIVS, SPHERE_TOPO);
        this.uvSphere = new LoadedMesh(device, uvMesh);

        const cubeMesh = genCubeSphere(SPHERE_SUBDIVS / 2, CUBE_TOPO);
        this.cubeSphere = new LoadedMesh(device, cubeMesh);

        const sphereShaderMod = device.createShaderModule({code: sphereShader});
        const cubeShaderMod = device.createShaderModule({code: cubeShader});

        const passBgLayout = device.createBindGroupLayout({
            entries: [{
                binding: 0,
                visibility: GPUShaderStage.VERTEX,
                buffer: {}
            }]
        });
        const sphereModelBgLayout = device.createBindGroupLayout({
            entries: [
                { // model
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {} 
                },
                { // tex
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {} 
                },
                { // sampler
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: {}
                }
            ]
        });

        const cubeModelBgLayout = device.createBindGroupLayout({
            entries: [
                { // model
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {}
                },
                { // tex
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        // important!
                        // this is how we "declare" to the pipeline that 
                        // we're expecting a cubemapped texture
                        viewDimension: 'cube'
                    }
                }, // samp
                {
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: {}
                }
            ]
        });
        
        // TODO
        // this.cubeModelBgLayout ...

        const spherePipelineLayout = device.createPipelineLayout({
            bindGroupLayouts: [passBgLayout, sphereModelBgLayout]
        });

        const cubePipelineLayout = device.createPipelineLayout({
            bindGroupLayouts: [passBgLayout, cubeModelBgLayout]
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
            layout: passBgLayout,
            entries: [{
                binding: 0,
                resource: this.projBuf
            }]
        });

        this.sphereModelMatBuf = device.createBuffer({
            size: 16 * 4,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
            label: "sphere mapped model buffer",
            mappedAtCreation: false
        });

        this.sphereSampler = device.createSampler({
            addressModeU: 'clamp-to-edge',
            addressModeV: 'clamp-to-edge',
            label: 'sphere map sampler',
            magFilter: 'linear',
            minFilter: 'linear',
        });
        this.cubeSampler = device.createSampler({
            addressModeU: 'clamp-to-edge',
            addressModeV: 'clamp-to-edge',
            magFilter: 'linear',
            minFilter: 'linear',
            label: 'cube map sampler'
        });

        this.sphereModelBg = device.createBindGroup({
            layout: sphereModelBgLayout,
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

        this.cubeModelBg = device.createBindGroup({
            layout: cubeModelBgLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.sphereModelMatBuf // TODO: change to different model
                },
                {
                    binding: 1,
                    resource: this.cubeMap.createView({
                        // we're creating a cubemap "view" of our texture so 
                        // internally, it's ready to be sampled as a cubemap.
                        dimension: 'cube',
                        arrayLayerCount: 6,
                    }),
                },
                {
                    binding: 2,
                    resource: this.cubeSampler
                }
            ]
        });


        this.sphereMapPipeline = device.createRenderPipeline({
            layout: spherePipelineLayout,
            vertex: {
                module: sphereShaderMod,
                buffers: [{
                    arrayStride: 3 * 4 + 2 * 4,
                    attributes: [
                        { // pos
                            format: 'float32x3',
                            offset: 0,
                            shaderLocation: 0,
                        },
                        { // uv
                            format: 'float32x2',
                            offset: 3 * 4,
                            shaderLocation: 1,
                        }
                    ]
                }]
            },
            fragment: {
                module: sphereShaderMod,
                targets: [{
                    format: this.format,
                }]
            },
            label: "sphere map pipeline",
            primitive: {
                cullMode: 'back',
                frontFace: 'ccw',
                topology: SPHERE_TOPO
            }
        });

        this.cubeMapPipeline = device.createRenderPipeline({
            layout: cubePipelineLayout,
            vertex: {
                module: cubeShaderMod,
                buffers: [{
                    arrayStride: 3 * 4,
                    attributes: [{
                        format: 'float32x3',
                        offset: 0,
                        shaderLocation: 0,
                    }]
                }]
            },
            fragment: {
                module: cubeShaderMod,
                targets: [{
                    format: this.format
                }]
            },
            label: 'cube map pipeline',
            primitive: {
                cullMode: 'back',
                frontFace: 'ccw',
                topology: CUBE_TOPO,
                stripIndexFormat: 'uint32'
            }
        });
    }

    sphereTurns: number = 0;
    update(dt: number) {
        this.sphereTurns += dt * ROT_SPEED_TURNS;
        this.sphereTurns %= ROT_PERIOD;

        const sphereModel = mat4.create();
        mat4.translate(sphereModel, sphereModel, SPHERE_MODEL_POS);
        mat4.rotateY(sphereModel, sphereModel, this.sphereTurns * TAU);
        mat4.rotateX(sphereModel, sphereModel, this.sphereTurns * TAU * 2);

        this.device.queue.writeBuffer(this.sphereModelMatBuf, 0, new Float32Array(sphereModel));
    }

    lastRender = performance.now();
    render(now: number) {
        let dt = (now - this.lastRender) / 1000;
        this.lastRender = now;
        this.update(dt);

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
                clearValue: {r: .7, g: .8, b: .9, a: 1.0},
            }]
        });
        pass.setPipeline(this.cubeMapPipeline);
        pass.setViewport(0, 0, c.canvas.width, c.canvas.height, 0, 1);
        pass.setBindGroup(0, this.passBg);
        /*
        pass.setBindGroup(1, this.sphereModelBg);
        pass.setVertexBuffer(0, this.uvSphere.verts);
        pass.setIndexBuffer(this.uvSphere.indis, 'uint32');
        pass.drawIndexed(this.uvSphere.nIndis);
        */
        pass.setBindGroup(1, this.cubeModelBg);
        pass.setVertexBuffer(0, this.cubeSphere.verts);
        pass.setIndexBuffer(this.cubeSphere.indis, 'uint32');
        pass.drawIndexed(this.cubeSphere.nIndis);
        pass.end();

        const commands = encoder.finish();
        d.queue.submit([commands]);
    }

    startRendering() {
        const renderAndRequeue = (now: number) => {
            this.render(now);
            requestAnimationFrame(renderAndRequeue);
        };
        requestAnimationFrame(renderAndRequeue);
    }
}