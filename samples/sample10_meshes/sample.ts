const shaderCode = /*wgsl*/`
@group(0) @binding(0) var<uniform> model: mat4x4<f32>;

@group(1) @binding(0) var<uniform> viewProj: mat4x4<f32>;

struct VertexOutput {
    @builtin(position) pos: vec4f,
    @location(0) color: vec3f,
};

@vertex fn vs(
    @location(0) pos: vec3f,
    @location(1) color: vec3f,
) -> VertexOutput
{
    var vo: VertexOutput;
    vo.pos = viewProj * model * vec4f(pos, 1.0);
    vo.color = color;
    return vo;
}

@fragment fn fs(vo: VertexOutput) -> @location(0) vec4f {
    return vec4f(vo.color, 1.0);
}

`;

/*
Here's a more complex mesh class that could be useful if you want to extend
the OBJ loader to support more attributes (which are determined at runtime):

export class MeshAttribute {
    name: string;
    nElems: number;

    constructor(name: string, nElems: number) {
        this.name = name;
        this.nElems = nElems;
    }
}

export class MeshData {
    indices: Uint32Array;
    nVertices: number = 0;
    attributes: MeshAttribute[] = [];
    attribData: Float32Array[] = [];

    constructor(attributes: MeshAttribute[], indices: number[], attribDatas: number[][]) {
        this.indices = new Uint32Array(indices);
        this.attributes = attributes;
        for (const attribData of attribDatas) {
            this.attribData.push(new Float32Array(attribData));
        }
    }

    calcPipelineAttributes(): GPUVertexAttribute[] {
        const attributeDescriptions: GPUVertexAttribute[] = [];

        let offset = 0;
        let shaderLoc = 0;
        for (const attr of this.attributes) {
            const format: GPUVertexFormat =
                attr.nElems == 1 ? 'float32' :
                attr.nElems == 2 ? 'float32x2' :
                attr.nElems == 3 ? 'float32x3' : 'float32x4';

            const desc: GPUVertexAttribute = {
                format,
                offset,
                shaderLocation: shaderLoc,
            };
            attributeDescriptions.push(desc);

            shaderLoc++;
            offset += attr.nElems * 4;
        }

        return attributeDescriptions;
    }
}

*/

import { vec3, mat4 } from 'gl-matrix'
import { SimpleNode } from '../sample09_nodes_and_cameras/sample.js';

export class SimpleMesh {
    indices: number[];
    positions: vec3[];
    colors: vec3[];
    nVerts: number;
    topology: GPUPrimitiveTopology;
    stride: number = 6 * 4; // 3 position floats, 3 color floats
    name: string;
    
    constructor (
        topo: GPUPrimitiveTopology,
        indices: number[],
        positions: vec3[],
        colors: vec3[],
        name?: string, // optional argument '?'
    ) {
        this.indices = indices;
        this.positions = positions;
        this.colors = colors;

        console.assert(positions.length == colors.length);
        this.nVerts = positions.length;
        this.topology = topo;
        this.name = name ?? 'unnamed' ; //'unnamed' will be used if name is undefined
    }
}

function simpleCubeMesh(): SimpleMesh {
    // vec3 is just a wrapper type around a tuple of 3 values.
    // we can construct them like this:
    const positions: vec3[] = [
        [-1,  1,  1],   // 0
        [-1, -1,  1],   // 1
        [ 1,  1,  1],   // 2
        [ 1, -1,  1],   // 3
        [ 1,  1, -1],   // 4
        [ 1, -1, -1],   // 5
        [-1,  1, -1],   // 6
        [-1, -1, -1],   // 7
    ];

    const colors: vec3[] = [
        [1, 0, 0],
        [0, 1, 0],
        [0, 0, 1],
        [1, 1, 0],
        [1, 0, 1],
        [0, 1, 1],
        [1, 1, 1],
        [0, 0, 0],
    ]

    const indis: number[] = [
        0, 1, 2, 3,
        4, 5,
        6, 7,
        0, 1, 0xFFFFFFFF,
        0, 2, 6, 4, 0xFFFFFFFF,
        3, 1, 5, 7
    ];

    return new SimpleMesh('triangle-strip', indis, positions, colors, 'cube');
}

class LoadedSimpleMesh {
    vertexBuffer: GPUBuffer;
    indexBuffer: GPUBuffer;
    nVerts: number;
    nIndis: number;
    topology: GPUPrimitiveTopology;

    constructor(device: GPUDevice, data: SimpleMesh) {
        this.nVerts = data.nVerts;
        this.nIndis = data.indices.length;
        this.topology = data.topology;

        const vertexData: number[] = [];
        for (let i = 0; i < data.nVerts; i++) {
            // the ... effectively unpacks the vector into 3 floats as arguments
            vertexData.push(...(data.positions[i] as vec3));
            vertexData.push(...(data.colors[i] as vec3));
        }

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


export async function loadObj(url: URL): Promise<SimpleMesh> {
    const response = await fetch(url);
    const blob = await response.blob();
    const text = await blob.text();

    const positions: vec3[] = [];
    const colors: vec3[] = [];
    const indis: number[] = [];

    for (const line of text.split(/\r?\n/)) {
        const parts = line.split(/\s+/)
        if (parts.length != 4) continue;
        
        switch (parts[0]) {
            case 'v':
                // vertex position line
                positions.push(vec3.fromValues( // vv '!' means "I promise it's not null or undefined"
                    Number.parseFloat(parts[1]!),
                    Number.parseFloat(parts[2]!),
                    Number.parseFloat(parts[3]!),
                ));
                // generate a random color
                colors.push(vec3.fromValues(Math.random(), Math.random(), Math.random()));
                break;
            case 'f': // for now, only simple faces, which are 3 indices, are supported
                indis.push(
                    Number.parseInt(parts[1]!) - 1, // obj files count from 1
                    Number.parseInt(parts[2]!) - 1, // webgpu counts from 0
                    Number.parseInt(parts[3]!) - 1, // so we subtract 1.
                );
                break
            case '#':
                break // comment means do nothing
            
            default:
                console.warn('unsupported attribute encountered in obj file:', parts);
        }
    }

    const mesh = new SimpleMesh('triangle-list', indis, positions, colors, url.toString());

    return mesh;
}

const TAU = Math.PI * 2;
const FOV = TAU / 6;
const ROT_SPEED = 1 / 4;

export class Sample10 {
    device: GPUDevice;
    context: GPUCanvasContext;
    
    mesh: LoadedSimpleMesh;
    cubeMesh: LoadedSimpleMesh;

    teapot: SimpleNode;
    cube: SimpleNode;
    camera: SimpleNode;

    matViewProj: GPUBuffer;
    bgViewProj: GPUBindGroup;

    triangleListPipeline: GPURenderPipeline;
    triangleStripPipeline: GPURenderPipeline;

    zBuffer: GPUTexture;

    format: GPUTextureFormat;

    lastUpdate: number = performance.now();

    constructor(
        device: GPUDevice,
        context: GPUCanvasContext,
        meshData: SimpleMesh,
    ) {
        this.device = device;
        this.context = context;
        this.format = (this.context.getCurrentTexture().format + '-srgb') as GPUTextureFormat;

        this.mesh = new LoadedSimpleMesh(device, meshData);
        this.cubeMesh = new LoadedSimpleMesh(device, simpleCubeMesh());

        const modelBgLayout = device.createBindGroupLayout({
            entries: [{
                binding: 0,
                visibility: GPUShaderStage.VERTEX,
                buffer: {}
            }]
        });

        const viewProjBgLayout = device.createBindGroupLayout({
            entries: [{
                binding: 0,
                visibility: GPUShaderStage.VERTEX,
                buffer: {}
            }]
        })

        this.zBuffer = device.createTexture({
            format: 'depth24plus-stencil8',
            size: {width: context.canvas.width, height: context.canvas.height},
            usage: GPUTextureUsage.RENDER_ATTACHMENT,
        });

        const shaderMod = device.createShaderModule({code: shaderCode});

        this.matViewProj = device.createBuffer({
            size: 16 * 4,
            usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.UNIFORM
        });
        this.bgViewProj = device.createBindGroup({
            layout: viewProjBgLayout,
            entries: [{
                binding: 0,
                resource: this.matViewProj
            }]
        });

        const listPipelineDesc: GPURenderPipelineDescriptor = {
            layout: device.createPipelineLayout({
                bindGroupLayouts: [modelBgLayout, viewProjBgLayout]
            }),
            vertex: {
                module: shaderMod,
                buffers: [{
                    arrayStride: meshData.stride,
                    attributes: [
                        { // position
                            format: 'float32x3',
                            offset: 0,
                            shaderLocation: 0,
                        },
                        { // color
                            format: 'float32x3',
                            offset: 3 * 4,
                            shaderLocation: 1,
                        },
                    ]
                }],
            },
            fragment: {
                module: shaderMod,
                targets: [{
                    format: this.format,
                }]
            },
            depthStencil: {
                format: this.zBuffer.format,
                depthWriteEnabled: true,
                depthCompare: 'less-equal',
            },
            primitive: {
                cullMode: 'back',
                frontFace: 'ccw',
                topology: 'triangle-list',
                // stripIndexFormat: 'uint32',
            },
        };

        this.triangleListPipeline = device.createRenderPipeline(listPipelineDesc);

        const stripPipelineDesc = listPipelineDesc;
        stripPipelineDesc.primitive!.topology = 'triangle-strip';
        stripPipelineDesc.primitive!.stripIndexFormat = 'uint32';
        this.triangleStripPipeline = device.createRenderPipeline(stripPipelineDesc);

        this.teapot = new SimpleNode('teapot', device, modelBgLayout);
        this.teapot.pos[2] = -10;
        this.teapot.pos[1] = -3;

        this.cube = new SimpleNode('cube', device, modelBgLayout);
        this.cube.pos[2] = -10;
        this.cube.pos[1] = 2;

        this.camera = new SimpleNode('camera', device, modelBgLayout);
    }

    startRendering(): void {
        const renderAndRequeue = (now: number) => {
            this.render(now);
            requestAnimationFrame(renderAndRequeue);
        }
        requestAnimationFrame(renderAndRequeue);
    }

    render(now: number): void {
        const dt = (this.lastUpdate - now) / 1000;
        this.lastUpdate = now;

        this.teapot.yaw += dt * ROT_SPEED;
        this.cube.pitch -= dt * ROT_SPEED;
        this.cube.yaw += dt * ROT_SPEED / 2;

        const encoder = this.device.createCommandEncoder();

        const canv = this.context.canvas;
        const aspectR = canv.width / canv.height;

        this.cube.updateMatrix(this.device);
        this.teapot.updateMatrix(this.device);
        this.camera.updateMatrix(this.device);

        const viewProj = mat4.create();
        mat4.perspective(viewProj, FOV / aspectR, aspectR, 1, 128);
        
        const view = mat4.create();
        mat4.invert(view, this.camera.matrix);
        mat4.mul(viewProj, viewProj, view);
        this.device.queue.writeBuffer(this.matViewProj, 0, new Float32Array(viewProj));

        const pass = encoder.beginRenderPass({
            colorAttachments: [{
                loadOp: 'clear',
                storeOp: 'store',
                view: this.context.getCurrentTexture().createView({
                    format: this.format
                }),
                clearValue: {r: .7, g: .8, b: .9, a: 1},
            }],
            depthStencilAttachment: {
                view: this.zBuffer,
                depthClearValue: 1,
                depthLoadOp: 'clear',
                depthStoreOp: 'store',
                stencilReadOnly: true,
                depthReadOnly: false,
            }
        });
        pass.setViewport(0, 0, canv.width, canv.height, 0, 1);

        pass.setPipeline(this.triangleListPipeline);
        pass.setBindGroup(1, this.bgViewProj);
        pass.setVertexBuffer(0, this.mesh.vertexBuffer); 
        pass.setIndexBuffer(this.mesh.indexBuffer, 'uint32');
        pass.setBindGroup(0, this.teapot.matrixBg);
        pass.drawIndexed(this.mesh.nIndis);

        pass.setPipeline(this.triangleStripPipeline);
        pass.setVertexBuffer(0, this.cubeMesh.vertexBuffer);
        pass.setIndexBuffer(this.cubeMesh.indexBuffer, 'uint32');
        pass.setBindGroup(0, this.cube.matrixBg);
        pass.drawIndexed(this.cubeMesh.nIndis);

        pass.end();
        
        const commands = encoder.finish();
        this.device.queue.submit([commands]);
    }
}