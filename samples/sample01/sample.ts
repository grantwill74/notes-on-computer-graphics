export function alertFail(err: Error): never {
    alert(err);
    throw err;
}


export async function initWebGpu():
    Promise<[GPUDevice, GPUCanvasContext,]> 
{
    const gpu = navigator.gpu;
    if (!gpu) {
        alertFail(new Error("Browser does not support WebGPU"));
    }

    const canvas = document.querySelector("canvas");
    
    if (!canvas) {
        alertFail(new Error("Web page does not have a canvas element."));
    }

    // The adapter represents an actual GPU (physical or virtual).
    // We don't have to provide a power preference, but I'm not going to 
    // need a lot of power, so let's save the energy:
    const adapter =
        await navigator.gpu.requestAdapter({powerPreference: "low-power"});

    if (!adapter) {
        alertFail(new Error("No WebGPU compatible GPU device available."));
    }
    
    // We request a device from the adapter. We can give it a list of features
    // we want to use, and also provide limits (such as how big the textures 
    // we need are). Again, the defaults are fine.
    const device = await adapter?.requestDevice({
        label: "Our basic WebGPU device", // optional label for error messages
        requiredFeatures: [], // we're good with the defaults
    });

    if (!device) {
        alertFail(new Error("unable to create a device."));
    }

    const context = canvas.getContext('webgpu');

    if (!context) {
        alertFail(new Error("unable to aquire a webgpu canvas context."));
    }

    context.configure({
        device: device,
        format: gpu.getPreferredCanvasFormat(),
        colorSpace: "srgb",
        alphaMode: "opaque",
    });

    return [device, context,];
}

export function renderSample01(
    device: GPUDevice,
    context: GPUCanvasContext,
): void
{
    const encoder = device.createCommandEncoder();
    const pass = encoder.beginRenderPass({
        colorAttachments: [
            {
                loadOp: "clear",
                storeOp: "store",
                view: context.getCurrentTexture(),
                clearValue: {r: 0.7, g: 0.8, b: 0.9, a: 1.0},
            }
        ]
    });
    pass.setViewport(0, 0, context.canvas.width, context.canvas.height, 0, 1);
    pass.end();

    const commands = encoder.finish();
    device.queue.submit([commands]);
}

