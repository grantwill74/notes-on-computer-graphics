const shaderCode = /*wgsl*/`
    @group(0) @binding(0) var<uniform> m_model: mat4x4<f32>;
    @group(0) @binding(1) var<uniform> m_normal: mat3x3<f32>;
    @group(0) @binding(2) var<uniform> mtl_ambient: vec3f;
    @group(0) @binding(3) var<uniform> mtl_diffuse: vec3f;

    @group(1) @binding(0) var<uniform> ambient_color: vec3f;
    @group(1) @binding(1) var<uniform> dir_light_dir: vec3f;
    @group(1) @binding(2) var<uniform> dir_light_color: vec3f;

    @group(2) @binding(0) var<uniform> m_viewProj: mat4x4<f32>;

    struct VertexOutput {
        @builtin(position)  pos: vec4f,
        @location(0)        norm: vec3f,
        @location(1)        color: vec3f,
    };

    @vertex fn vs(
        @location(0) pos: vec3f,
        @location(1) normal: vec3f,
    ) -> VertexOutput
    {
        var vo: VertexOutput;
        vo.pos = m_viewProj * m_model * vec4f(pos, 1);
        vo.norm = m_normal * normal;

        let diffuse_color = dot(dir_light_dir, vo.norm) * dir_light_color;
        vo.color = ambient_color + diffuse_color;
        
        return vo;
    }

    @fragment fn fs(vo: VertexOutput) -> @location(0) vec4f {
        return vec4f(vo.color, 1.0);
    }
`;


import { vec3, mat4, mat3 } from "gl-matrix"

export class Mesh {
    indices: number[];
    vertData: number[];
    nVerts: number;
    stride: number = 6 * 4; // 3 position floats, 3 normal/color floats
    name: string;
    
    constructor (
        indices: number[],
        positions: vec3[],
        name?: string, // optional argument '?'
    ) {
        this.indices = indices;
        // this.vertData = vertData;

        this.nVerts = positions.length;
        this.name = name ?? 'unnamed' ; //'unnamed' will be used if name is undefined

        const vertHasFaces: number[][] = new Array(this.nVerts);
        const faceHasNormal: vec3[] = new Array(Math.floor(indices.length / 3));
        for (let i = 0; i < indices.length; i += 3) {
            const faceNo = Math.floor(i / 3);
            vertHasFaces[indices[i]!] ??= [];
            vertHasFaces[indices[i]!]!.push(faceNo);
            vertHasFaces[indices[i + 1]!] ??= [];
            vertHasFaces[indices[i + 1]!]!.push(faceNo);
            vertHasFaces[indices[i + 2]!] ??= [];
            vertHasFaces[indices[i + 2]!]!.push(faceNo);

            const a = positions[indices[i]!]!;
            const b = positions[indices[i + 1]!]!;
            const c = positions[indices[i + 2]!]!;

            const d = vec3.create();
            const e = vec3.create();
            const n = vec3.create();
            
            vec3.sub(d, b, a);
            vec3.sub(e, c, a);
            vec3.cross(n, d, e);

            faceHasNormal[faceNo] = n;
        }
        this.vertData = [];
        for (let i = 0; i < this.nVerts; i++) {
            // isolated vert
            if (!vertHasFaces[i]) {
                this.vertData.push(0, 0, 0, 0, 0, 0);
                continue;
            };

            const n = vec3.create();
            for (let face of vertHasFaces[i]!) {
                vec3.add(n, n, faceHasNormal[face]!);
            }
            vec3.normalize(n, n);

            this.vertData.push(...positions[i]!, ...n);
        }
    }
}

export async function loadObj(url: URL): Promise<Mesh> {
    const response = await fetch(url);
    const blob = await response.blob();
    const text = await blob.text();

    const positions: vec3[] = [];
    const indis: number[] = [];

    for (const line of text.split(/\r?\n/)) {
        const l = line.trim();
        if (l == '') continue;
        if (l.startsWith('#')) continue;
        const parts = l.split(/\s+/)
        if (parts.length == 0) continue;
        
        switch (parts[0]) {
            case 'v':
                // vertex position line
                positions.push(vec3.fromValues( // vv '!' means "I promise it's not null or undefined"
                    Number.parseFloat(parts[1]!),
                    Number.parseFloat(parts[2]!),
                    Number.parseFloat(parts[3]!),
                ));
                break;
            case 'f': // for now, only simple faces, which are 3 indices, are supported
                indis.push(
                    Number.parseInt(parts[1]!) - 1, // obj files count from 1
                    Number.parseInt(parts[2]!) - 1, // webgpu counts from 0
                    Number.parseInt(parts[3]!) - 1, // so we subtract 1.
                );
                break
            
            default:
                console.warn('unsupported attribute encountered in obj file:', parts);
        }
    }

    const mesh = new Mesh(indis, positions, url.toString());

    return mesh;
}


function simpleCubeMesh(): Mesh {
    // vec3 is just a wrapper type around a tuple of 3 values.
    // we can construct them like this:
    const verts: vec3[] = [
        [-1,  1,  1],   // 0
        [-1, -1,  1],   // 1
        [ 1,  1,  1],   // 2
        [ 1, -1,  1],   // 3
        [ 1,  1, -1],   // 4
        [ 1, -1, -1],   // 5
        [-1,  1, -1],   // 6
        [-1, -1, -1],   // 7
    ];

    const indis: number[] =[
        0, 1, 2, 2, 1, 3,
        2, 3, 4, 4, 3, 5,
        4, 5, 6, 6, 5, 7,
        6, 7, 0, 0, 7, 1,
        0, 2, 6, 6, 2, 4,
        3, 1, 5, 5, 1, 7,
    ]
    
    return new Mesh(indis, verts, 'cube');
}

class LoadedMesh {
    vertexBuffer: GPUBuffer;
    indexBuffer: GPUBuffer;
    nVerts: number;
    nIndis: number;

    constructor(device: GPUDevice, data: Mesh) {
        this.nVerts = data.nVerts;
        this.nIndis = data.indices.length;

        const vertexData = new Float32Array(data.vertData);

        this.vertexBuffer = device.createBuffer({
            size: data.stride * this.nVerts,
            usage: GPUBufferUsage.VERTEX,
            mappedAtCreation: true,
            label: 'verts: ' + data.name
        });
        (new Float32Array(this.vertexBuffer.getMappedRange())).set(vertexData);
        this.vertexBuffer.unmap();

        this.indexBuffer = device.createBuffer({
            size: data.indices.length * 4,
            usage: GPUBufferUsage.INDEX,
            label: 'indis: ' + data.name,
            mappedAtCreation: true,
        });
        (new Uint32Array(this.indexBuffer.getMappedRange())).set(data.indices);
        this.indexBuffer.unmap();
    }
}

const TAU = Math.PI * 2;
const FOV = TAU / 6;
const LIGHT_ROT_SPEED = TAU / 4;
const MESH_ROT_SPEED = -TAU / 16;

export class Sample12 {
    device: GPUDevice;
    context: GPUCanvasContext;

    meshes: Map<string, Mesh>;
    loaded: Map<string, LoadedMesh> = new Map();
    currentMesh: string;

    matProj: mat4 = mat4.create();
    matModel: mat4 = mat4.create();
    matNormal: mat3 = mat3.create();
    mtlAmbient: vec3 = [1, 1, 1];
    mtlDiffuse: vec3 = [1, 1, 1];
    ambientColor: vec3 = [0.2, 0.15, 0.1];
    dirLightPos: vec3 = vec3.create();
    dirLightColor: vec3 = [0, 1, 0];

    matProjBuf: GPUBuffer;
    matModelBuf: GPUBuffer;
    matNormalBuf: GPUBuffer;
    mtlAmbientBuf: GPUBuffer;
    mtlDiffuseBuf: GPUBuffer;
    ambientColorBuf: GPUBuffer;
    dirLightPosBuf: GPUBuffer;
    dirLightColorBuf: GPUBuffer;

    format: GPUTextureFormat;

    bgProj: GPUBindGroup;
    bgLight: GPUBindGroup;
    bgModel: GPUBindGroup;

    pipeline: GPURenderPipeline;
    zBuffer: GPUTexture;

    lastUpdate: number = performance.now();

    constructor(
        device: GPUDevice,
        context: GPUCanvasContext,
        meshes: Map<string, Mesh>,
    ) {
        this.device = device;
        this.context = context;
        this.meshes = meshes;
        
        const whichMesh = Math.floor(Math.random() * meshes.size);
        this.currentMesh = this.meshes.keys().drop(whichMesh).next().value!;

        for (let [name, mesh] of meshes) {
            this.loaded.set(name, new LoadedMesh(device, mesh));
        }

        this.format = ((this.context.getCurrentTexture().format as string) + '-srgb') as GPUTextureFormat;
        const aspectR = this.context.canvas.width / this.context.canvas.height;

        // finally using the correct FOV-y
        const fov_y = 2 * Math.atan2(Math.tan(FOV/2), aspectR);

        // set up lights and local matrices
        vec3.normalize(this.dirLightPos, [1, 1, -1]);
        mat4.perspectiveZO(this.matProj, fov_y, aspectR, 1, 128);
        const view = mat4.create();
        mat4.translate(view, view, [0, 0, -10]);
        mat4.mul(this.matProj, this.matProj, view);

        const usage = GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST;

        // create buffers
        this.matProjBuf = device.createBuffer({
            size: 16 * 4,
            usage,
            label: "projection matrix buffer",
            mappedAtCreation: true
        });
        (new Float32Array(this.matProjBuf.getMappedRange())).set(this.matProj);
        this.matProjBuf.unmap();

        this.matModelBuf = device.createBuffer({
            size: 16 * 4,
            usage,
            label: "model matrix buffer",
        });
        this.matNormalBuf = device.createBuffer({
            size: 12 * 4, // IMPORTANT: it's not 3 * 3, it's actually 3 4-d basis vectors!
            usage,
            label: "normal matrix buffer",
        });
        this.ambientColorBuf = device.createBuffer({
            size: 3 * 4,
            usage,
            label: "ambient color buffer"
        });
        this.mtlAmbientBuf = device.createBuffer({
            size: 3 * 4,
            usage,
            label: "material ambient factor buffer"
        });
        this.mtlDiffuseBuf = device.createBuffer({
            size: 3 * 4,
            usage,
            label: "material diffuse factor buffer"
        });
        this.dirLightPosBuf = device.createBuffer({
            size: 4 * 4, // vectors are always 4 elements in size, even when it's a vec3
            usage,       // that's why a 3x3 matrix requires 12 elements of storage.
            label: "directional light position buffer"
        });
        this.dirLightColorBuf = device.createBuffer({
            size: 4 * 4,
            usage,
            label: "directional light color buffer"
        });

        // create bind group layouts
        const bgModelLayout = device.createBindGroupLayout({
            entries: [
                { // model matrix
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {}
                },
                { // normal matrix
                    binding: 1,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {}
                },
                { // ambient factor
                    binding: 2,
                    // using both stages so we can freely switch between
                    // fragment lighting and vertex lighting
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: {}
                },
                { // diffuse factor
                    binding: 3,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: {}
                }
            ],
            label: "model and normal matrix bind group layout"
        });

        const bgLightLayout = device.createBindGroupLayout({
            entries: [
                {   // ambient_color
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: {}
                },
                {   // pos dir
                    binding: 1,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: {}
                },
                {   // pos color
                    binding: 2,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: {}
                },
            ],
            label: "lighting bind group layout"
        });

        const bgProjLayout = device.createBindGroupLayout({
            entries: [{
                binding: 0,
                visibility: GPUShaderStage.VERTEX,
                buffer: {}
            }]
        });

        // create bind groups
        this.bgModel = device.createBindGroup({
            layout: bgModelLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.matModelBuf
                },
                {
                    binding: 1,
                    resource: this.matNormalBuf
                },
                {
                    binding: 2,
                    resource: this.mtlAmbientBuf
                },
                {
                    binding: 3,
                    resource: this.mtlDiffuseBuf
                }
            ],
            label: "model bind group"
        });

        this.bgLight = device.createBindGroup({
            layout: bgLightLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.ambientColorBuf
                },
                {
                    binding: 1,
                    resource: this.dirLightPosBuf
                },
                {
                    binding: 2,
                    resource: this.dirLightColorBuf
                }
            ],
            label: "lighting bind group"
        });

        this.bgProj = device.createBindGroup({
            layout: bgProjLayout,
            entries: [{
                binding: 0,
                resource: this.matProjBuf
            }]
        });

        this.zBuffer = device.createTexture({
            format: 'depth24plus-stencil8',
            size: { width: context.canvas.width, height: context.canvas.height },
            usage: GPUTextureUsage.RENDER_ATTACHMENT,
        });

        const shaderMod = device.createShaderModule({code: shaderCode});

        const pipelineLayout = device.createPipelineLayout({
            bindGroupLayouts: [bgModelLayout, bgLightLayout, bgProjLayout],
        });
        this.pipeline = device.createRenderPipeline({
            layout: pipelineLayout,
            vertex: {
                module: shaderMod,
                buffers: [{
                    arrayStride: 3 * 4 + 3 * 4,
                    attributes: [
                        {   // position
                            format: 'float32x3',
                            offset: 0,
                            shaderLocation: 0
                        },
                        {   // normal
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
                    format: this.format,
                }]
            },
            primitive: {
                cullMode: 'back',
                frontFace: 'ccw',
                topology: 'triangle-list',
            },
            depthStencil: {
                format: 'depth24plus-stencil8',
                depthCompare: 'less-equal',
                depthWriteEnabled: true,
            }
        });
    }

    update(t: number, dt: number) {
        mat4.rotateY(this.matModel, mat4.create(), MESH_ROT_SPEED * t);
        mat3.normalFromMat4(this.matNormal, this.matModel);

        const w = this.device.queue.writeBuffer.bind(this.device.queue);
        const f32a = Float32Array;
        w(this.ambientColorBuf, 0, new f32a(this.ambientColor));
        w(this.dirLightColorBuf, 0, new f32a(this.dirLightColor));
        w(this.dirLightPosBuf, 0, new f32a(this.dirLightPos));
        w(this.mtlAmbientBuf, 0, new f32a(this.mtlAmbient));
        w(this.mtlDiffuseBuf, 0, new f32a(this.mtlDiffuse));
        w(this.matProjBuf, 0, new f32a(this.matProj));
        w(this.matModelBuf, 0, new f32a(this.matModel));

        // mat normal is special. a 3x3 matrix needs to be expanded into 
        // 3 4-element basis vectors. if our matrix library was intended for
        // webgpu instead of GL, this could be its internal layout.
        // it's something to look into for future iterations.
        const n = this.matNormal;
        const unpacked = [
            n[0], n[1], n[2], 0,
            n[3], n[4], n[5], 0,
            n[6], n[7], n[8], 0
        ];
        w(this.matNormalBuf, 0, new f32a(unpacked));
    }

    render(now: number) {
        const dt = (now - this.lastUpdate) / 1000;
        this.lastUpdate = now;        
        this.update(now / 1000, dt);


        const c = this.context;
        const encoder = this.device.createCommandEncoder();
        const curMesh = this.loaded.get(this.currentMesh)!;

        const pass = encoder.beginRenderPass({
            colorAttachments: [{
                loadOp: 'clear',
                storeOp: 'store',
                view: c.getCurrentTexture().createView({
                    format: this.format
                }),
                clearValue: {r: .7, g: .8, b: .9, a: 1},
            }],
            depthStencilAttachment: {
                view: this.zBuffer,
                depthClearValue: 1,
                depthLoadOp: 'clear',
                depthReadOnly: false,
                depthStoreOp: 'store',
                stencilReadOnly: true
            }
        });

        pass.setBindGroup(2, this.bgProj);
        pass.setBindGroup(1, this.bgLight);
        pass.setBindGroup(0, this.bgModel);
        pass.setViewport(0, 0, c.canvas.width, c.canvas.height, 0, 1);
        pass.setPipeline(this.pipeline);
        pass.setVertexBuffer(0, curMesh.vertexBuffer);
        pass.setIndexBuffer(curMesh.indexBuffer, 'uint32');
        
        pass.drawIndexed(curMesh.nIndis);
        pass.end();

        const commands = encoder.finish();
        this.device.queue.submit([commands]);
    }

    startRendering() {
        const renderAndRequeue = (now: number) => {
            this.render(now);
            requestAnimationFrame(renderAndRequeue);
        };
        requestAnimationFrame(renderAndRequeue);
    }
}