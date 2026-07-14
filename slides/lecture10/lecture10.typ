#set document(title: "Notes on Computer Graphics: Lecture 10")

#import "@preview/touying:0.7.4": *
#import themes.simple: *
#import "@preview/shadowed:0.3.0": shadow
#import "../util.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/cetz:0.5.2" as cetz: canvas, draw

#show link: set text(blue)
#show: slide-theme


#title-slide[
  = Computer Graphics: Lecture 10
  == Animation, culling, and Depth-buffers

  \
  \
  \
  \
  Slide Deck © Grant Williams, 2026, License: #link("https://creativecommons.org/licenses/by-sa/4.0/deed.en")[CC-BY-SA 4.0] 
]


== Welcome back!

Last time:
- We learned about affine matrices.
- We learned about the homogenous coordinates needed to make use of them. Our points are now vectors with a 1 in the w-place.
- We learned how to send matrix data to the GPU.
- We stretched and squashed some triangles

== This time

We have one main objective: animate a spinning figure.

In order to accomplish this cleanly, we will have to examine two more techniques:
+ Back-face culling
+ Depth buffering (AKA the Z-buffer)

== Animation

Let's stop having all the power of our GPU used to render one frame.

It's meant to be able to generate dozens or even hundreds of frames every second, so lets learn how to do that.

It's slightly more involved than just drawing a bunch of pictures, though.

In particular: [how many pictures do we need to draw?]

== Frame rates

We call the number of images we can draw in a certain amount of time the *frame rate*.

Frame rate is measured most commonly in *Frames Per Second (FPS)*.

In computer graphics, given that we often want to optimize to reduce the time it takes to render one frame, we also like to use *MilliSeconds Per Frame (msPF)* too.

The reciprocal is nice, because an increase of 30 FPS is meaningless if we already are at 1000 FPS, but huge if we're at 10 FPS. But reducing by 1 millisecond per frame always means the same level of improvement.

== Frame rates (2)

The typical human eyes and brain can perceive up to 12 images per second as distinct images.

Once the number goes higher than that, we start to perceive it as motion.

We can still pick out variations in luminance at extremely high framerates, however (#link("https://www.nature.com/articles/srep07861", "Source")). Up to 500 Hz.

However, for motion pictures, 24 frames per second is widely used and generally considered fine.

== Frame rates in interactive software

#stack(dir: ltr, spacing: 4%,
box(width: 48%)[
So if 24 FPS is fine, why are there gamer monitors out there that advertise a refresh rate of 240 Hz.?

Afterall, famously influential shooter Goldeneye 007 barely managed hit 30 FPS some of the time, and #link("https://www.ign.com/articles/1997/08/26/goldeneye-007", "contemporary critics didn't seem to mind"). 

[thoughts?]
],
box(width: 48%)[
  #image("screens/goldeneye_4player.webp", alt: "screenshot of the game Goldeneye 007, in 4-player split-screen multiplayer.")
  #place(horizon + right, dy: 47%, game-name([Goldeneye 007]))
  #text(20pt)[This game in this scene was likely struggling to hit even the 12 FPS required for motion perception.]
]
)

== Games are different

The reason is that games are interactive.

The frame rate doesn't just determine how smooth the animation is, it also determines how long you have to wait until seeing the result of your actions.

This turns out to have a large impact on how skilled people are (#link("https://web.cs.wpi.edu/~claypool/papers/fr-rez/paper.pdf", [source])). More frames means more chances to aim adjust.

Subjectively, I can also say that higher frame rates just make games more fun in general.

== What frame rate to target?

So, logically, that means we want to render as many frames as possible...

Except, your monitor is only capable of displaying a certain frame rate.

If your monitor only supports 120 Hz., displaying more is not only pointless, it can actually hurt the image quality.

The issue is that the monitor draws the frame from top to bottom. If you draw too quickly, you can actually replace the frame its drawing _as it's being drawn_, causing a visible discontinuity known as #link("https://gamersnexus.net/Screen%20Tearing", [*tearing*]).

== Tearing 

#figure(
  [
  #image("screens/screen-tearing.jpg", height: 80%, alt: "a game screenshot in which the frame was replaced after about a fourth of the time through the screen drawing cycle, causing a noticable seam between the camera being in one place in one frame and a different place in the next.")
  #place(top + right, dx: -8%, dy: 1%, game-name("Dead Rising 2"))
  ],
  numbering: none,
  caption: "Notice the seam about a quarter of the way down the image."
)

#focus-slide("Questions?")

== Separating setup vs rendering

Previously, when we were drawing one frame, we didn't really differentiate between the setup code and the code that actually drew the frame.

=== Setup
- Compiling the shader module
- Creating the buffers, bind groups, and textures
- Creating the pipeline

=== Actual rendering
- Creating the encoder
- Building and submitting the pass

== Things that have to happen every frame

Creating the command encoder has to happen every frame. It is illegal to reuse an already `.finish()`ed command encoder.

Therefore, at the very least, the code where we define our render pass and submit the commands to the device's queue has to happen once per frame. We will be doing this often.

== Things that only have to happen once

On the other hand, if something only has to happen once, it is wastful to do it every frame.

Compiling the shader is slow, and it would  be ridiculous to do it often.

Same with creating buffers. It's slow and involves allocating memory.

Same with textures.

In general, we want to do these things once, then reuse them.

Creating textures and geometry (vertex data) usually happens once while a game is _loading_. Once it's loaded, the frames are fast to draw.

== Setting this up

From now on, our samples are going to be *classes*.

A class in TypeScript works similarly to classes in other languages you are familiar with, such as Java and Python.

When we have a class, we can use the `new` keyword to create an instance of it. The instance will have a copy of all the fields of the class, and we can invoke methods on it.

```ts
const myInstance = new MyClass(dataTheClassNeeds);
```

`myInstance` is now an object, and its type is `MyClass`.


== Fields

In order for an object to be useful, it needs to have data inside. #footnote[If an object does not have data, then you're just bundling a bunch of functions together. This is fine, but the object is just a module.]

The definitions of what kinds of data an object will have are *fields*.

Defining fields in TypeScript looks just like defining parameters:
```ts
class Foo{
  someField: number = 0; // default value of 0.
}
// now we can make a Foo and access the field
const f = new Foo(); console.log(f.someField);

```

== Methods

The main purpose of classes is to bundle *state* (the fields of an instance) with special functions that modify that state.

These functions are called *methods*.

To make a method in typescript, we have the name of the method, followed by a parameter list and return type. *There is no special keyword for creating methods*.

```ts
class Foo {
  someField: number = 0;
  incField(): void { this.someField++; } // make it bigger
}
```

== The `this` keyword

To access the instance that the method was invoked on, use `this`.

Suppose we did this:
```ts
const f = new Foo();
f.incField();
```

Inside the `incField` method, `this` would refer to `f`, since that is the instance the method is being invoked on.

We are going to take the `someField` field inside that instance, and increment it by one.

== Constructors

The purpose of the constructor is to run after memory has been allocated for an object in order to initialize it to a known state.

TypeScript is very picky about constructors. _Every field_ must be fully initialized to an instance of its type by the constructor.

```ts
class Foo {
  someField: number;
  constructor() {
    this.someField = 7; //*required*
  }
}
```

== Constructors (2)

The constructor is a special method named `constructor`.

It is called after `new` is invoked. The arguments it receives are the arguments that are passed to `new`, and they must match.

If we declared `someField: number | undefined`, we could skip defining it, because every field starts out `undefined` by default, and we're saying "it can be a number or it can be undefined."

But `undefined` values are annoying, so we want to avoid them.

Default values are assigned before the constructor runs, and the constructor does not have to overwrite them.

== That's it for OO 

That's the only OO we're going to cover, but it should be enough to start making our samples as classes.

This will be convenient, as it will let us put the setup code that needs to happen in the constructor or in a function that runs before the constructor (like for loading textures).

Then, we can call render many times and it won't have to re-compute everything.

Let's take questions, then draw a single animated quad.

#focus-slide("Questions?")

== Let's animate a quad: the class 

We'll start by defining all the data we want to create up front:

```ts
class Sample07 {
    device: GPUDevice;
    context: GPUCanvasContext;
    pipeline: GPURenderPipeline;
    matBuf: GPUBuffer;
    vertBuf: GPUBuffer;
    textureFormat: GPUTextureFormat;
    bindGroup: GPUBindGroup;

    rotationTurns: number;
    lastRenderTime: number;
    ...
}
```

== The class (2)

Here, all the data we want to reuse or have access to when rendering is made into a field.

We'll receive the device and context from the caller. We'll initialize the pipeline, buffers, and bind groups in the constructor.

The last two fields are needed to keep track of our animation. We're going to rotate the model around smoothly, so we want to keep track of how rotated it is (in turns).

Lastly, keeping track of the last render time lets us compute how much more we need to rotate the model.

== The constructor

Inside our class, we have a constructor. It's the constructor's job to make sure to initialize all those fields:

```ts
constructor(device: GPUDevice, context: GPUCanvasContext) {
  this.device = device;
  this.context = context;
  this.rotationTurns = 0;
  this.textureFormat =
    (context.getCurrentTexture().format + '-srgb') as
            GPUTextureFormat;
  this.lastRenderTime = performance.now(); 
```

Let's quickly discuss `performance.now()`...

== The performance timer

Most games and simulations need more precise timing than the basic timer the operating system and web browser use.

For these special applications, modern operating systems have a special timer called a "high performance timer"

This timer effectly tracks the number of CPU clock cycles that have passed since a program started.

`performance` is an instance of this timer which every web page has access to. `performance.now()` returns the number of milliseconds since the webpage started to be loaded. Every time we render, we'll take the difference between `now` and `lastRenderTime` to get the delta.

== Let's animate a quad: the vertices


We are going to locate it a bit offset in space, because it's eventually going to be the side of a cube that is centered at the origin:

```ts
const vertArray = new Float32Array([
    -.3, -.3, -.3,  1, 0, 0, // offset z by -0.3
     .3, -.3, -.3,  1, 0, 0,
     .3,  .3, -.3,  1, 0, 0,
    -.3, -.3, -.3,  1, 0, 0,
     .3,  .3, -.3,  1, 0, 0,
    -.3,  .3, -.3,  1, 0, 0,
]); // we're defining XYZ position and RGB color
```

== Creating the buffers

Creating a buffer is pretty verbose. We've already seen how to do it for vertex buffers and for matrices.

However, _these_ matrices are a different: they will change every frame.

Therfore, when we create the buffer for our matrix, we're going to hardcode its size, and have `mappedAtCreation` be false.

#[
  #set text(20pt)
```ts
this.matBuf = device.createBuffer({
    size: 16 * 4,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    label: "matrix buffer",
    mappedAtCreation: false,
});
```
]

== Creating the buffers (2)

The `COPY_DST` usage is important because we are going to use a different mechanism to load our matrix buffer.

We are not going to map it and then `set` the data. Instead, we are going to use `device.queue.writeBuffer`. This function will overwrite buffer data on the GPU, but it requires the buffer support `COPY_DST`.

We'll show how to use that method in a bit. For now, let's continue discussing the constructor.

(all of this can be found, with some additional code we will discuss in the lecture, in `sample07`. I'm leaving a lot out because it can't all possibly fit in the lecture slides)

== Creating the bind group layout

```ts
const bgLayout = device.createBindGroupLayout({
    entries: [{
        binding: 0, // the only binding is one matrix
        visibility: GPUShaderStage.VERTEX,
        buffer: {}
    }]
});
```

Our pipeline needs to know what bind groups can be bound to it, so we create the layout.

This isn't a field because we can retrieve it out of the pipeline later if we need to, so there's no need to store a separate copy of it.

== The shader

Let's discuss the shader these bind groups will be getting attached to.

#[
  #set text(20pt)
  ```wgsl
const shaderCode = /*wgsl*/`
@group(0) @binding(0)
var<uniform> model: mat4x4<f32>;

struct VertexOutput {
    @builtin(position) pos: vec4f,
    @location(0) color: vec4f,
};
```
]

There will be one uniform variable: the model matrix. It will be a 4-by-4 matrix just like we learned. This is why our bind group has one binding, and why there is only one bind group.

== The shader (2)


#[
  #set text(20pt)
```wgsl
@vertex fn vs(
    @location(0) pos: vec3f,
    @location(1) color: vec3f
) -> VertexOutput
{
    var vo: VertexOutput;
    vo.pos = model * vec4f(pos, 1.0);
    vo.color = vec4f(color, 1.0);
    return vo;
}
```
]

The vertex shader is going to take that model matrix and multiply it by every point it receives. So if we pass a rotation shader that rotates an amount determined by the current time, we can smoothly rotate.

== The shader (3)

#[
```wgsl
@fragment fn fs(vo: VertexOutput) -> @location(0) vec4f {
    return vo.color;
}
`;
  ```
]

Lastly, we just return the color inside the vertex output. 

The `@builtin(position)` value inside the vertex output is used to determine where to draw the pixels. This happens implicitly in between the vertex shader and rasterization steps of the render pipeline.

== Creating the pipeline

Speaking of the pipeline...

```ts
this.pipeline = device.createRenderPipeline({
    layout: device.createPipelineLayout({
        bindGroupLayouts: [bgLayout],
    }),
    ...    
```

Make sure it knows about our bind group layouts.

The fragment and vertex shader are (for now) identical to how they have been.

== Creating the bind group

The last step in the constructor: create the bind group

```ts
this.bindGroup = device.createBindGroup({
    entries: [{
        binding: 0,
        resource: this.matBuf,
    }],
    layout: bgLayout
});
```

Any questions about what goes in the constructor? We're initializing all the values that only need to be set once so we don't have to do it each frame.

#focus-slide("Questions?")

== Updating the matrix

Now things are going to change a little.

We're going to define a function that will be called whenever we need to determine the model's position:

#[
  #set text(20pt)
```ts
update(dt: number): void {
    const model = mat4.create();
    mat4.translate(model, model, vec3.fromValues(0, 0, .5));
    mat4.rotateX(model, model, -.05 * TAU); // left handed: negate amount 
    mat4.rotateY(model, model, -this.rotationTurns * TAU); 
    this.rotationTurns += dt * TURNS_PER_SEC;
    this.rotationTurns %= 1; // wrap around once we hit 1 turn
    this.device.queue.writeBuffer(
      this.matBuf, 0, new Float32Array(model));
}
```
]

== Updating the matrix (2)

#[
  #set text(22pt)
The first thing we do is create a new matrix. This matrix will _first_, rotate around the y axis based on the amount of rotation we've added so far.

Then it will rotate by a fixed offset forward around X. (We flip the sign because we're using a right-handed matrix in a left-handed system)

Then it will translate the object forward (we're still using left-handed coordinates, so .5 means .5 into the screen).

If we didn't translate forward, the model might be cut off, since we defined it in the negative Z position. Remember that it needs to be between 0 and 1 to show up at all.

Also remember: the transformations are in _reverse order_. `rotateY` is first!
]

== Updating the matrix (3)

Then we use `device.queue.writeBuffer`

This method takes a buffer, which in our case is the one we're using for our matrix.  It also takes an offset: which for us is 0 here (we want to write over the whole thing, not skip any bytes).

Finally, it takes an array of data to copy.

We give it the new matrix we just calculated. It will overwrite the old matrix. The next time our shader runs, it will be using the updated matrix.

== Updating the matrix (4)

That TURNS_PER_SEC constant is up to you. I'm using 0.25, so it turns slowly enough for me to see that it's working smoothly.

In Javascript we can use the mod operators `%` and `%=` on floats. Since 1.5 turns is equivalent to 0.5 turns, we use `%= 1` to keep only the fractional part of the float.

Javascript numbers are 64-bit doubles, so we don't really have to do this. However, if we used 32-bit floats, we would run out of precision after an hour or two if we didn't. It's actually a common bug in even modern games to keep adding to a float without wrapping it until the addition starts underflowing.

== Bind groups

You might wonder why we don't need to create a new bind group. Why can we reuse the old one?

The bind group stores the mapping between uniforms and the location of the data, but it doesn't store the data itself.

We _could_ create another bind group. But we'd need to allocate a new matrix, which would be slower than just overwriting the old one.

Finally, the `writeBuffer` method requires that the `COPY_DST` usage be enabled on the buffer. If we didn't do this, we would have to map the buffer. Aquiring a map after creation is inconvenient and requires async code.

== What about animation

I still haven't discussed how to animate things. Luckily, the API for it is pretty simple (at least, compared with everything else we've been doing)

There is a function you can call called `requestAnimationFrame(r)`.

This function itself takes a function, `r`, which is a render function.

We use this function to alert the browser that we want it to draw something to the screen when it's ready.

When the browser is ready to paint the screen, it will call the function you gave it as a *callback*. 

== Callbacks

A *callback* is a function that is called by a different system than the one which defined it.

We define a function called `render`, and we can pass that function to `requestAnimationFrame()`.

However, that will only work once.

To run it over and over again, at the end of our function, we'll have it re-queue itself by calling `requestAnimationFrame` again.

== `startRendering`

```ts
startRendering(): void {
    const renderAndQueue = (now: number) => {
        this.render(now);
        requestAnimationFrame(renderAndQueue);
    }
    renderAndQueue(performance.now());
}
```

Here, we define a local function using anonymous function notation. `const renderAndQueue = (...) => { ... }` is mostly equivalent to `function renderAndQueue(...) { ... }` except it only lives inside the current scope

== `startRendering` (2)

Inside that function, we call render, and then we call `requestAnimationFrame` on the anonymous function.

This will loop over and over: render the frame, then ask to be rendered again in the future.

Our function `renderAndQueue` takes a `now` variable. `requestAnimationFrame` will automatically pass the current performance timer to it when it calls it. The first time we call it ourselves with the performance time.

== `requestAnimationFrame`

Usually `requestAnimationFrame` will wait until the monitor is ready to refresh, which means if we always request as soon as the old frame is rendered, we'll end up matching the framerate of the monitor.

It also will pause automatically if the user navigates away from the tab, which is a nice battery saver (it would be very annoying if a game continued to burn power if the user had it in what they thought was an inactive tab).

== The result

Check out `lecture10/screens/rotating_quad.mp4` to see an example of what you should see if you're following along so far.

It's just a spinning quad, that is rotated according to the matrices we provided, and offset from the center of the screen.

Note: the actual sample draws a whole cube, so you will need to substitute just the vertex buffer from the slides.

#focus-slide("Questions so far?")

== Adding the rest of the cube

Well shoot, now that we have animation, we can draw an _entire cube_ instead of just a quad. We can actually see a spinning 3D figure instead of just a 2D one!

Check the sample code to see me actually specify 12 whole triangles (2 per side, 6 sides of a cube), but I'll save you the pain.

Let's see what it looks it. I will open up: `lecture10/screens/no-culling.mp4`.

Uh oh, that's weird. What's going on?

== What's going on

Yeah so it's not supposed to look like this:
#image("screens/no-culling.png", height: 80%, alt: "A cube in which some of the sides are being drawn over others in a weird way. In particular, the front two faces of the cube are being drawn over by the back, spoiling the illusion of depth.")

== What's going on (2)

The problem is that web GPU is drawing the triangles in an arbitrary order. _They are not being sorted by distance_.

It just so happens that at some rotations, it looks okay, but at other rotations, we are drawing the back sides on top of the front sides in a weird way.

This completely spoils the 3D effect and looks bad.

So what do we do? Do we have to break our cube up into pieces to order the draw calls? I hope not, that would be way too slow.

== How to fix it

This has been a problem as long as 3D graphics has existed, so it is not surprising that there is a simple solution that was available even on really early hardware.

I'm not talking about the depth buffer (yet), I'm talking about something even simpler: *backface culling*.

A *backface* is a face (triangle) that is pointing _away_ from us. 

We want to *cull* it, which means prevent it from being drawn.

Why do we want to do that?

== Face Culling

Face culling serves multiple purposes:
- It makes it so that the back of a solid object does not draw over its front.
- If an object is solid, it's pointless to draw the triangles that face away from us because they will be hidden from view anyway, so it's a nice optimization even if we had some other way of blocking them.
- It ends up being required for correct transparent rendering.

So, how does the system know whether a face is facing towards us or facing away from us?

== How face culling works 

Simply put: the cross product between two of the face's edges.

By default, if that cross product is facing out of the screen, then the face is *front facing*. Otherwise, it is *back facing* (if it's perfectly sideways it also does not produce visible fragments).

This means we must always define our triangles in the same order: either clockwise or counter-clockwise.

If we mix the order, we won't be able to keep track of whether the cross product is positive or not.

== Winding order

The order in which triangles are specified is called *winding order*.

The standard winding order for most 3D systems and file formats is counter-clockwise.

Therefore, from now on, let's stick to counter-clockwise winding!

But how do we tell WebGPU to use culling?

== Enabling culling
