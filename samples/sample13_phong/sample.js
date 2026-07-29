const shaderCode = /*wgsl*/ `
    @group(0) @binding(0) var<uniform> m_model: mat4x4<f32>;
    @group(0) @binding(1) var<uniform> m_normal: mat3x3<f32>;

    struct Material {
        ambient: vec3f, // bytes 0-11, padding 4
        diffuse: vec3f, // bytes 16-27, padding 4
        specular: vec3f, // bytes 32-43
        shininess: f32,  // bytes 44-47 (occupies where the padding would be)
    };

    @group(0) @binding(2) var<uniform> mtl: Material;

    struct Light {
        pos_dir: vec4f, // can be a position or a direction depending on w
        color: vec3f,
        atten: vec3f,   // x = constant term, y = linear term, z = quadratic term
    };

    @group(1) @binding(0) var<uniform> ambient_color: vec3f;
    @group(1) @binding(1) var<uniform> dir_light: Light;
    @group(1) @binding(2) var<uniform> point_light: Light;


    @group(2) @binding(0) var<uniform> m_viewProj: mat4x4<f32>;
    // world level camera position
    @group(2) @binding(1) var<uniform> eye_pos: vec3f;

    struct VertexOutput {
        @builtin(position)  pos: vec4f,
        @location(0)        norm: vec3f,
        // I left world_pos in here in case you want to try doing 
        // world-space fragment lighting with point lights.
        @location(1)        world_pos: vec4f,
        @location(2)        color: vec3f,
    };

    fn diffuse_color(
        light_dir: vec3f,
        light_color: vec3f,
        norm: vec3f,
    )-> vec3f
    {
        let brightness = max(0.0, dot(light_dir, norm));
        return brightness * light_color * mtl.diffuse;
    }

    fn specular_color(
        light_dir: vec3f,
        light_color: vec3f,
        norm: vec3f,
        eye_dir: vec3f,
        shininess: f32
    )-> vec3f
    {
        let reflected = reflect(-light_dir, norm);
        let brightness = max(0.0, dot(reflected, eye_dir));
        let shine = pow(brightness, shininess);
        return light_color * shine * mtl.specular;
    }

    fn attenuate(
        input_color: vec3f,
        distance: f32,
        factors: vec3f,
    ) -> vec3f
    {
        return input_color / (
            factors.x +
            factors.y * distance +
            factors.z * distance * distance  
        );
    }

    @vertex fn vs(
        @location(0) pos: vec3f,
        @location(1) normal: vec3f,
    ) -> VertexOutput
    {
        var vo: VertexOutput;
        vo.world_pos = m_model * vec4f(pos, 1);

        let eye_dir = normalize(eye_pos - vo.world_pos.xyz);
        // we can also do lighting in view or even projection space.
        // this removes the need to track the position of the eye.
        // instead, the -view_direction would point to the eye.

        vo.pos = m_viewProj * vo.world_pos;
        vo.norm = normalize(m_normal * normal);
        let color_from_dir_light =
            diffuse_color(dir_light.pos_dir.xyz, dir_light.color, vo.norm) +
            specular_color(dir_light.pos_dir.xyz, dir_light.color, vo.norm, eye_dir, mtl.shininess);
        let point_light_off = point_light.pos_dir.xyz - vo.world_pos.xyz;
        let point_light_dir = normalize(point_light_off);
        let distance_to_point_light = length(point_light_off);
        // small optimization: you can compute distance first, then divide dir by it
        // downside: length works in the 0-distance case, but 0/0 will be NaN.
        let color_from_point_light =
            diffuse_color(
                point_light_dir,
                point_light.color,
                vo.norm) +
            specular_color(
                point_light_dir,
                point_light.color,
                vo.norm, eye_dir, mtl.shininess);

        vo.color = ambient_color * mtl.ambient +
            color_from_dir_light +
            attenuate(color_from_point_light, distance_to_point_light, point_light.atten);
        
        return vo;
    }

    @fragment fn fs(vo: VertexOutput) -> @location(0) vec4f {
        return vec4f(vo.color, 1.0);
    }
`;
import { vec3, vec4, mat4, mat3 } from "gl-matrix";
import { Mesh, LoadedMesh } from "../sample12_lights/sample.js";
function packMaterial(ambient, diffuse, specular, shininess) {
    return new Float32Array([
        ...ambient, 0, // add the 0 for padding
        ...diffuse, 0,
        ...specular, // whoops, no padding here, shininess goes there
        shininess
    ]);
}
function packLight(posOrDir, color, attenuation = [1, 0, 0]) {
    return new Float32Array([...posOrDir, ...color, 0, ...attenuation, 0]);
}
const TAU = Math.PI * 2;
const FOV = TAU / 6;
const LIGHT_ROT_SPEED = TAU / 4;
const MESH_ROT_SPEED = -TAU / 16;
export class Sample13 {
    device;
    context;
    meshes;
    loaded = new Map();
    currentMesh;
    matProj = mat4.create();
    matModel = mat4.create();
    matNormal = mat3.create();
    mtlAmbient = [1, 1, 1];
    mtlDiffuse = [1, 1, 1];
    mtlSpecular = [1, 1, 1];
    mtlShiny = 10;
    ambientColor = [0.02, 0.02, 0.02];
    dirLightDir = [1, 0, 0, 0];
    dirLightColor = [.15, .7, .30];
    pointLightPos = [-1, 0, 0, 1];
    pointLightColor = [.8, .1, .3];
    pointLightAtten = [1, .7, 1.0];
    pointLightDist = 1;
    eyePos = [0, 0, 1.5];
    matProjBuf;
    matModelBuf;
    matNormalBuf;
    mtlBuf;
    ambientColorBuf;
    dirLightBuf;
    pointLightBuf;
    eyePosBuf;
    format;
    bgProj;
    bgLight;
    bgModel;
    pipeline;
    zBuffer;
    lastUpdate = performance.now();
    constructor(device, context, meshes) {
        this.device = device;
        this.context = context;
        this.meshes = meshes;
        const whichMesh = Math.floor(Math.random() * meshes.size);
        this.currentMesh = this.meshes.keys().drop(whichMesh).next().value;
        for (let [name, mesh] of meshes) {
            this.loaded.set(name, new LoadedMesh(device, mesh));
        }
        this.format = (this.context.getCurrentTexture().format + '-srgb');
        const aspectR = this.context.canvas.width / this.context.canvas.height;
        // finally using the correct FOV-y
        const fov_y = 2 * Math.atan2(Math.tan(FOV / 2), aspectR);
        // set up lights and local matrices
        vec3.normalize(this.dirLightDir, this.dirLightDir);
        mat4.perspectiveZO(this.matProj, fov_y, aspectR, 0.25, 5);
        const view = mat4.create();
        const reverseEyePos = [-this.eyePos[0], -this.eyePos[1], -this.eyePos[2]];
        mat4.translate(view, view, reverseEyePos);
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
        this.mtlBuf = device.createBuffer({
            // 3 aligned vec3s. The shininess parameter hides in the last padding. 
            size: 4 * 4 + 4 * 4 + 4 * 4,
            usage,
            label: "material buffer"
        });
        this.dirLightBuf = device.createBuffer({
            size: 4 * 4 + 4 * 4 + 4 * 4,
            usage,
            label: "directional light"
        });
        this.pointLightBuf = device.createBuffer({
            size: 4 * 4 + 4 * 4 + 4 * 4,
            usage,
            label: "positional light"
        });
        this.eyePosBuf = device.createBuffer({
            size: 3 * 4,
            usage,
            label: "eye position"
        });
        // create bind group layouts
        const bgModelLayout = device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {}
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {}
                },
                {
                    binding: 2,
                    // using both stages so we can freely switch between
                    // fragment lighting and vertex lighting
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: {}
                },
            ],
            label: "model and normal matrix bind group layout"
        });
        const bgLightLayout = device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: {}
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: {}
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: {}
                }
            ],
            label: "lighting bind group layout"
        });
        const bgProjLayout = device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {}
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {}
                }
            ]
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
                    resource: this.mtlBuf
                },
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
                    resource: this.dirLightBuf
                },
                {
                    binding: 2,
                    resource: this.pointLightBuf
                }
            ],
            label: "lighting bind group"
        });
        this.bgProj = device.createBindGroup({
            layout: bgProjLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.matProjBuf
                },
                {
                    binding: 1,
                    resource: this.eyePosBuf
                }
            ]
        });
        this.zBuffer = device.createTexture({
            format: 'depth24plus-stencil8',
            size: { width: context.canvas.width, height: context.canvas.height },
            usage: GPUTextureUsage.RENDER_ATTACHMENT,
        });
        const shaderMod = device.createShaderModule({ code: shaderCode });
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
                            {
                                format: 'float32x3',
                                offset: 0,
                                shaderLocation: 0
                            },
                            {
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
    changeCurrentMesh(change) {
        this.currentMesh = change;
    }
    changeDirLightColor(change) {
        this.dirLightColor = change;
    }
    changePointLightColor(change) {
        this.pointLightColor = change;
    }
    changePointLightDistance(change) {
        this.pointLightDist = change;
    }
    changePointLightAttenuation(change) {
        this.pointLightAtten = change;
    }
    changeAmbientColor(change) {
        this.ambientColor = change;
    }
    changeMaterialAmbient(change) {
        this.mtlAmbient = change;
    }
    changeMaterialDiffuse(change) {
        this.mtlDiffuse = change;
    }
    changeMaterialSpecular(change) {
        this.mtlSpecular = change;
    }
    changeMaterialShininess(change) {
        this.mtlShiny = change;
    }
    update(t, dt) {
        // rotate the lights
        this.dirLightDir = [1, 0, 0, 0];
        const matLight = mat4.create();
        mat4.rotateY(matLight, matLight, -LIGHT_ROT_SPEED * t);
        vec4.transformMat4(this.dirLightDir, this.dirLightDir, matLight);
        // the point light will be a quarter turn behind the directional light
        this.pointLightPos = [0, 0, 1, 1];
        mat4.scale(matLight, matLight, [this.pointLightDist, this.pointLightDist, this.pointLightDist]);
        vec4.transformMat4(this.pointLightPos, this.pointLightPos, matLight);
        // scale, shift, and rotate the model
        const curMesh = this.meshes.get(this.currentMesh);
        mat4.rotateY(this.matModel, mat4.create(), MESH_ROT_SPEED * t);
        const scale = 1 / curMesh.widestExtent;
        mat4.scale(this.matModel, this.matModel, [scale, scale, scale]);
        mat4.translate(this.matModel, this.matModel, curMesh.offset);
        mat3.normalFromMat4(this.matNormal, this.matModel);
        const w = this.device.queue.writeBuffer.bind(this.device.queue);
        const f32a = Float32Array;
        w(this.ambientColorBuf, 0, new f32a(this.ambientColor));
        w(this.dirLightBuf, 0, packLight(this.dirLightDir, this.dirLightColor));
        w(this.pointLightBuf, 0, packLight(this.pointLightPos, this.pointLightColor, this.pointLightAtten));
        w(this.mtlBuf, 0, packMaterial(this.mtlAmbient, this.mtlDiffuse, this.mtlSpecular, this.mtlShiny));
        w(this.matProjBuf, 0, new f32a(this.matProj));
        w(this.eyePosBuf, 0, new f32a(this.eyePos));
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
    render(now) {
        const dt = (now - this.lastUpdate) / 1000;
        this.lastUpdate = now;
        this.update(now / 1000, dt);
        const c = this.context;
        const encoder = this.device.createCommandEncoder();
        const curMesh = this.loaded.get(this.currentMesh);
        const pass = encoder.beginRenderPass({
            colorAttachments: [{
                    loadOp: 'clear',
                    storeOp: 'store',
                    view: c.getCurrentTexture().createView({
                        format: this.format
                    }),
                    clearValue: { r: .7, g: .8, b: .9, a: 1 },
                }],
            depthStencilAttachment: {
                view: this.zBuffer.createView(),
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
        const renderAndRequeue = (now) => {
            this.render(now);
            requestAnimationFrame(renderAndRequeue);
        };
        requestAnimationFrame(renderAndRequeue);
    }
}
//# sourceMappingURL=sample.js.map