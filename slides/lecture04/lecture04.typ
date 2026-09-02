#set document(title: "Notes on Computer Graphics: Lecture 4")

#import "@preview/touying:0.7.4": *
#import themes.simple: *
#import "@preview/shadowed:0.3.0": shadow
#import "../util.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/cetz:0.5.2" as cetz: canvas, draw

#show link: set text(blue)
#show: slide-theme


#title-slide[
  = Computer Graphics: Lecture 4
  == Your first Triangles

  \
  \
  \
  \
  Slide Deck © Grant Williams, 2026, License: #link("https://creativecommons.org/licenses/by-sa/4.0/deed.en")[CC-BY-SA 4.0] 
]

== Welcome Back!
Last time we developed our first 3D graphics application!

But it wasn't very 3D...or 2D...or any D.

That's because we were just clearing the screen.

Obviously that's not very interesting. We want to draw things. And what is the simplest thing to draw? Triangles!

== Quick review

Before we start drawing things, let's review what we know:
- There's something called the 3D graphics pipeline. The triangles go through that pipeline and are transformed into pixels.
- We don't just call a "drawTriangles" function and walk away. Instead, we build a command buffer that tells the GPU to draw the triangles. We compile that buffer, and we send it to the GPU.
- The result is copied into the canvas in our webpage (or the background of a window if on desktop).

So, how do we do that?

== Commands to draw triangles

Previously, we cleared our screen by defining a render pass with the correct clear color and attachment operations:

#[
  #set text(size: 20pt)
```ts
const encoder = device.createCommandEncoder();
const pass = encoder.beginRenderPass({
    colorAttachments: [{
        loadOp: 'clear',
        storeOp: 'store',
        view: context.getCurrentTexture(),
        clearValue: {r: .7, g: .8, b: .9, a: 1.0},
    }]
});
pass.setViewport(0, 0, context.canvas.width, context.canvas.height, 0, 1);
pass.end();
device.queue.submit([encoder.finish()]);
```
]

== Drawing 

There are (at least) two more commands we have to add to draw.

The first is that we have to tell it which pipeline to use. We haven't defined a pipeline yet, so this is a placeholder.

Then, we have to tell it to `draw` some points. We tell it to draw 3 points, which it will stitch together into a triangle.

```ts
pass.setViewport(...); // more on viewports later
pass.setPipeline(pipeline); // we must create this "pipeline"
pass.draw(3); // draw 3 points.
pass.end();
```

== The importance of a pipeline

Drawing requires a pipeline. You can't draw without a pipeline because it wouldn't know where to get the data.

"Okay, you want me to draw a triangle, but where? With what points? What color? What shaders do you want me to run?"

The pipeline will describe where to fetch the raw data, what shaders to run on it, where to put the results, and some other interesting things.

We're working backwards. I find it's easier to remember if we start with what we want (the draw call) and work backwards to build the objects we need. Let's do the "next" step and build a pipeline.

== Building a pipeline

We build a pipeline by calling `device.createRenderPipeline(...)`#footnote[There is also a `createComputePipeline` for running raw code on the GPU. The compute pipeline is simpler, but we need all the special hidden features WebGPU supports for triangle rendering.]

#place(dy:5%)[
  #set text(size: 18pt)
```ts
const pipeline = device.createRenderPipeline({
    layout: 'auto',
    vertex: {
        module: shaderMod, // we haven't defined shaderMod yet
    }, 
    fragment: {
        module: shaderMod,
        targets: [
            {format: context.getCurrentTexture().format,}
        ],
    },
});
```
]

== Describing the pipeline

Let's talk about what went into that pipeline.

First, we specified its `layout` as `'auto'`. The layout describes the order and location of external data that is available to the shaders. We don't need any yet, so we set this to be automatically determined.

Then, we have two descriptors for `vertex` and `fragment`. These describe the vertex and fragment (pixel) shaders. We'll talk about what these shaders do in a bit, but know that they appear in practically every 3D pipeline. We will define the `shaderMod` variable next.

`targets` gives information about the data the fragment shader is writing to. Again, we'll cover this soon.

== Building a shader module

Think back to when you learned C. You did not run the C code directly in an interpreter: instead you compiled it into an object file. Object files are binary code that can be linked together into an executable or library.

In the same way, we compile shader code into object files (the "linking" isn't something we have to worry about).

So, we give WebGPU our shader source code and it will compile it into a binary that can be further transformed, loaded, or linked by the GPU.#footnote[The binary format is called SPIR-V (pronounced "spear-vee" and standing for "standard portable intermediate representation...vee" The V doesn't officially stand for anything, but some people think it stands for "Vulkan", because that's the API it was intended for.]

== Building a shader module

Building a shader module for the pipeline is easy:

```ts
const shaderMod = device.createShaderModule({
    code: stringThatHasTheShaderCode,
    label: "a description of the shader" // optional
});
```

There is one optional field where you can provide compilation hints, but we won't bother to use it.

And now we can't avoid it anymore. We have to write the shader code. That `stringThatHasTheShaderCode` has to have something in it.

But first...

#focus-slide("Questions?")

== WGSL

Most modern 3D graphics workflows let you program shaders in whatever language you want, and compile them into SPIR-V.

Unfortunately, claiming reasons involving a legal dispute, Apple was unable to agree to a format controlled by an outside party (#link("https://docs.google.com/document/d/1F6ns6I3zs-2JL_dT9hOkX_253vEtKxuUkTGvxpuv8Ac/edit?tab=t.0#heading=h.hp3f2zbslxr9", "source")).

Instead, the committee decided on a programming language called WGSL (WebGPU shading language, originally named "tint", pronounced "wigg-sl")

== WGSL syntax

This language is somewhat controversial. It's rather verbose, and its syntax appears to be based on Rust and Typescript rather than C (like the old OpenGL shading language was). 

However, since we are using Typescript, that doesn't seem like a bad thing. Personally, I don't find the syntax too horrible (but I am familiar with Rust, which it resembles most closely).

Let's write a simple shader for drawing our triangles. I'll show the shader first, and then explain it...

== Basic triangle shader
#[
  #set text(size: 20pt)
```wgsl
// we store it in a string. /*wgsl*/ is for syntax highlighting with plugins.
const vertsInShaderCode = /*wgsl*/` //<- this is a backtick string: ` not '
const vert_positions: array<vec4f, 3> = array(
    vec4f(-.75, -.75, 0, 1),
    vec4f( .75, -.75, 0, 1),
    vec4f(   0,  .75, 0, 1),
);

@vertex fn vs(@builtin(vertex_index) index:u32) -> @builtin(position) vec4f {
    return vert_positions[index];
}

@fragment fn fs() -> @location(0) vec4f {
    return vec4f(0.4, 0.8, 0.3, 1.0);
}
` // <- closing backtick
```
]

== Basic triangle shader

Okay, let's explain what's going on

This shader is defined inside our Typescript source code. It's stored inside of a variable.

We could store it in an external file and load it, but this would require using some web features I don't want to cover yet (`fetch` and `async`)

We use a backtick string, officially called a "template literal". In Typescript, you can define strings with `""` or `''` like python, but you can also define them with ``` `` ```

We do this because template strings can stretch across lines.

== Basic triangle shader (2)

The next thing to discuss is the `/*wgsl*/` comment at the top. 

This isn't required, it's just a comment, so it gets stripped out and ignored by the compiler/browser. 

It's there because I'm using a plugin that allows WGSL source code to be syntax highlighted inside of Typescript or Javascript files.

I recommend using it too, it's called "WGSL Literal" in the VSCode marketplace. (there's also a WGSL one for `.wgsl` files for when you get to a point where you can load an external file).

== Basic triangle shader (3)

Let's talk about the body of the shader.

#[
  #set text(size: 20pt)
```wgsl
const vert_positions: array<vec4f, 3> = array(
    vec4f(-.75, -.75, 0, 1),
    vec4f( .75, -.75, 0, 1),
    vec4f(   0,  .75, 0, 1),
);
```
]

There's a lot going on here:
- `const` is for defining constants. It's like `const` in Typescript, except you _cannot_ modify its fields. It's a true compile-time constant.
- Types are specified like in Typescript or Rust. A colon followed by the type name. In this case `array<...>` is defining a type.

== Basic triangle shader (4)

#[
  #set text(size: 20pt)
```wgsl
const vert_positions: array<vec4f, 3> = array(
    vec4f(-.75, -.75, 0, 1),
    vec4f( .75, -.75, 0, 1),
    vec4f(   0,  .75, 0, 1),
);
```
]

- When `array<...>` defines a type, we use angle brackets to describe what it's an array of and how many elements it has.
- `vec4f` is the element type. This means a vector of 4 elements, each of which are floats. It's a shortcut for writing `vec4<f32>`. `f32` is how `float` is written in this language (like in Rust).
- Why are there 4 dimensional vectors? We'll talk about that in a bit.
- The `3` is the length of the array. 

== Basic triangle shader (5)

#[
  #set text(size: 20pt)
```wgsl
const vert_positions: array<vec4f, 3> = array(
    vec4f(-.75, -.75, 0, 1),
    vec4f( .75, -.75, 0, 1),
    vec4f(   0,  .75, 0, 1),
);
```
]

- so `array` is a type, but it's also a constructor. This is a common pattern in WGSL. We use `array(...)` to define the array.
- Inside the array are 4 values: x, y, z, and w. What coordinate system are we using? We'll talk more about it later in this lecture, but basically, #math.equation(alt: "x equals minus 1, y equals minus 1", $x=-1, y=-1$) is the bottom left of the screen and #math.equation(alt: "x equals 1, y equals 1", $x=1, y=1$) is the top right. Don't worry about z and w for now.
- We terminate the definition with a `;`, just like in C.

== Basic triangle shader (6)

Okay, we've seen "what" the array is, but not "why" the array...

This array describes the 3 vertex positions of our triangle. 

This information is used by the vertex shader:
#[
  #set text(size: 20pt)
```wgsl
@vertex fn vs(@builtin(vertex_index) index: u32) -> 
  @builtin(position) vec4f
{
    return vert_positions[index];
}
```
]

This is a single function, which is the entrypoint (main) for the vertex shader. The `@vertex` attribute tells us that.

== Basic triangle shader (7)

#[
  #set text(size: 20pt)
```wgsl
@vertex fn vs(@builtin(vertex_index) index: u32) -> 
  @builtin(position) vec4f
{
    return vert_positions[index];
}
```
]

- The `fn` keyword defines a function.
- `vs` is the name of the function. It can be anything we want: I name it `vs` for "vertex shader".
- We can specify the name in the pipeline instead and leave `@vertex` off if we want, but I never find that more convenient than `@vertex`.
- The vertex shader takes one piece of data for every vertex: the _index_ of that vertex (i.e., which vertex it is).

== Basic triangle shader (8)

When we draw a 3D object (called a mesh), it will contain usually hundreds or thousands of vertices.

Each vertex has a number describing it, called its index. 

Indices usually start at 0 and go upwards as far as we need.

Every time we want to draw a vertex, the vertex shader is called on it, like a function. It can receive whatever data about that vertex we want. Each piece of data is a parameter of the vertex shader function.

== Basic triangle shader (9)

#[
  #set text(size: 20pt)
```wgsl
@vertex fn vs(@builtin(vertex_index) index: u32) -> 
  @builtin(position) vec4f
{
    return vert_positions[index];
}
```
]

WGSL must know where every variable comes from. Saying `@builtin(vertex_index)` means that the parameter will come from the built-in index value of the vertex.

We are basically renaming this special variable to `index`, and saying that we want it to be a `u32` (an unsigned 32-bit integer). We could have made it a `u16` since we don't have very many points.

== Basic triangle shader (10)

If we had left off the `@builtin(vertex_index)` from in front of the parameter, we would have gotten an error, because the system would not know where to get the parameter from.

Similarly, the `->` is a return value. This return value is also going to a built-in location: `position`. 

Every vertex is required to return something with the `@builtin(position)` set. The position is important because it is clipped and transformed further after it is returned by the vertex shader, so the system has to know which return value is the position (there can be more than one returned vector).

#focus-slide("With me so far?")

== In between the vertex and fragment shader

The purpose of the vertex shader is to bring a vertex from *model space* (i.e., the coordinates used in the 3D editor, like Blender) into *clip space* (the [-1, 1] coordinate system we mentioned briefly).

In our vertex shader, we predefined the coordinates of the triangle in an array. The shader uses the index to look up the specific coordinates for a given vertex number, and it returns that value.

After the vertex shader runs, the underlying 3D hardware links the vertices into triangles, figures out which pixels they cover, and runs the fragment shader on each of those pixels. So, let's talk about the fragment shader...

== Basic triangle shader (11)

#[
  #set text(size: 20pt)
```wgsl
@fragment fn fs() -> @location(0) vec4f {
    return vec4f(0.4, 0.8, 0.3, 1.0);
}
```
]
- We know this is the fragment shader because of the `@fragment`
- Fragment shaders normally take data about the triangle they are on the surface of, but this fragment shader doesn't take any parameters.
- The fragment shader also returns a `vec4f`, but it's interpreted as a color. Instead of `xyzw` coordinates, it has `rgba` coordinates, for "red", "green", "blue", and "alpha"#footnote[Technically, it's the same data type. You can refer to a vector with .xyz or with .rgb, and they are interchangable. `r` just means `x`, g means `y`, etc. We'll talk about alpha when we get to color blending]. 

== Basic triangle shader (12)

```wgsl
@fragment fn fs() -> @location(0) vec4f {
    return vec4f(0.4, 0.8, 0.3, 1.0);
}
```

The fragment shader is returning a color at `@location(0)`. Fragment shaders can return more than one thing. In our case, 0 means the 0th render attachment, which is the one we're drawing to our canvas.

The actual shader is very simple: it returns a constant color value (a greenish color) for every pixel. So the triangle the GPU draws will have a single constant color. Not very interesting, but we'll do more with colors, textures, and shading, later.

== A Summary 

- We defined our shader code in WGSL as a string
- We compiled it with `device.createShaderModule(...)`
- We created a pipeline with `device.createPipeline(...)`
- The pipeline had fields for layout (auto), a vertex shader, and a fragment shader. These fields told it to use the shader module we compiled. They also described the output format in the fragment shader.
- We created a command encoder. We defined a render pass with the correct attachment information (clear color, operations, and target).
- We defined the pass: its viewport, the pipeline, and we said `draw`
- We ended the pass, finished the command, and sent it to the GPU

== Finishing up

Go ahead and follow along as best you can from the slides.

I recommend trying to do as much from memory as you can to help the different steps stick in your memory. 

However, you can also look at `sample02` if you get stuck.

Try your best to remember the steps. Quiz yourself and see if you can do it from scratch. This will be worth it when we get to more complicated techniques.

== The triangle

#place(center, dy: 10%, image("screens/triangle.png", alt: "screenshot of the rendered triangle", height: 85%))

#focus-slide("Questions?")

== Let's learn the pipeline properly now

There are two things that are missing from our understanding so far:
+ The pipeline has a lot of implicit stages. How are those coordinates interpreted? How does the system know how to fill in the triangle?
+ We do not want to hardcode the coordinates of the triangle in the shader. One shader is often useful for many objects. The memory available inside the shader is quite limited. We want to store the triangle in a buffer instead.

Let's start by better understanding the pipeline

== Understanding the sequence of operations

We submitted a command buffer to the GPU. One command was `draw`.

The GPU will invoke the vertex shader once for every drawn vertex. Our command was `draw(3)`, so the vertex shader will be called 3 times. 

Each of these calls is totally independent, so the GPU is free to run each one on its own thread. 

Most GPUs have hundreds or even thousands of independent computation units (e.g., CUDA cores or stream processors), so even if we draw 50 vertices there's a decent chance their vertex shaders would all run at the same time.

== The pipeline: vertex shader input

Each vertex has a unique number, and that number is passed to its shader as an argument. We could have set up our pipeline to pass more data besides that number (and we will do so momentarilly).

The vertex shader has one purpose: to return a _new_ vertex.

Why? Because the raw vertices usually came out of a 3D modelling program. They aren't facing the right way with respect to the camera. They aren't at the correct position in the world. They might be #link("https://en.wikipedia.org/wiki/T-pose", "T-posed") instead of animated.

== The pipeline: vertex shader output

#[
  #set text(23pt)
So the vertex shader runs and applies all those transformations.

It then returns a vertex that is in *clip coordinates*.

The 3D system will draw any vertex that is inside the clipping volume, where x and y are both in the inclusive range [-w, w], and z is in the inclusive range [0, w].

We will explain w later, but for now, w will be 1, so this volume is usually [-1, 1] by [-1, 1] by [0, 1].

The axes are similar to what you learned in math: positive x goes right, positive y goes up. Z is a little different: by default positive z goes _into_ the screen. We'll be changing that later.
]

== Primitive assembly

After running the vertex shader independently on each vertex, the next stage in the pipeline is *primitive assembly*

This means that 3 vertices are linked together into triangles.

This happens based on the order of vertices. By default, every group of three vertices is linked into one triangle. (there are other topologies)

We drew 3 vertices, so we produced one triangle. If we had drawn 6, we would have produced 2.

You can't have part of a triangle, so if we had drawn 2, nothing would be shown, and drawing 5 would result in 3.

== Clipping 

The next stage is clipping, which means ensuring that every visible triangle is entirely in view. The purpose of this is to make it so that we don't have to worry about pixels going off screen (and having to check every single pixel would be slow).
- If an the triangle is entirely out of view, it is removed from further processing. This can dramatically speed things up.
- If the entire triangle is in view, it is not clipped at all.
- If the triangle is partially out of view, it is modified or broken up into multiple in-view triangles.

But what is _in view_? Answer: whatever is in the clipping volume.

== The clipping volume

#let fig = figure(
  alt: "A simple rendering of the clipping volume.",
  canvas(length: 8cm, {
  import draw: *

  let nbl = (-1, -1, 0)
  let ntl = (-1,  1, 0)
  let ntr = ( 1,  1, 0)
  let nbr = ( 1, -1, 0)
  let fbl = (-1, -1, 1)
  let ftl = (-1,  1, 1)
  let ftr = ( 1,  1, 1)
  let fbr = ( 1, -1, 1)

  let t1 = (-.6, .3, 0.5)
  let t2 = (.5, -.45, 0.5)
  let t3 = (.9, .45, 0.5)
  
  perspective({
    set-viewport((-1, -1, 0), (1, 1, 1), bounds: (4, 4, -2))
    line(nbl, ntl, ntr, nbr, close: true)
    line(fbl, ftl, ftr, fbr, close: true, fill: rgb(70%, 80%, 90%, 25%))
    line(nbl, fbl)
    line(ntl, ftl)
    line(ntr, ftr)
    line(nbr, fbr)
    line(t1, t2, t3, close: true, fill: green)
    content((0, -1.2, 0), [x])
    content((-1.2, 0, 0), [y])
    content((-1.6, 0.65, 1), [z])
  })
  })
)

#left-right(fig, [
  #set align(left)
  This is what the clipping volume looks like.

  The GPU only draws whatever is inside here.

  The vertices inside the volume are _after_ running the vertex shader on the input. The vertex shader is supposed to produce vertices relative to this volume.
])

== The pipeline: Clipping

#let fig = figure(
  alt: "A triangle has two vertices outside of the clipping volume, so it is shrunk until the external portion is no longer present, and the whole triangle is in-bounds.",
  canvas(length: 7cm, {
  import draw: *

  let nbl = (-1, -1, 0)
  let ntl = (-1,  1, 0)
  let ntr = ( 1,  1, 0)
  let nbr = ( 1, -1, 0)
  let fbl = (-1, -1, 1)
  let ftl = (-1,  1, 1)
  let ftr = ( 1,  1, 1)
  let fbr = ( 1, -1, 1)

  let t1 = (-.6, .3, 0.5)
  let t2 = (2.2, -.45, 0.5)
  let t2c = (1.0, -.14, 0.5)
  let t3 = (2.2, .45, 0.5)
  let t3c = (1.0, .39, 0.5)

  perspective({
    set-viewport((-1, -1, 0), (1, 1, 1), bounds: (4, 4, -2))
    line(nbl, ntl, ntr, nbr, close: true)
    line(fbl, ftl, ftr, fbr, close: true, fill: rgb(70%, 80%, 90%, 25%))
    line(nbl, fbl)
    line(ntl, ftl)
    line(ntr, ftr)
    line(nbr, fbr)
    line(t1, t2c, t3c, close: true, fill: green)
    line(t2c, t3c, t3, t2, close: true, fill: rgb(25%, 25%, 25%, 25%))

    content((0, -1.2, 0), [x])
    content((-1.2, 0, 0), [y])
    content((-1.6, 0.65, 1), [z])
  })
  })
)

#left-right(fig, )[
  If the vertex shader returns a triangle with 1 or more points outside, those points get clipped (shown with 2 points outside).

  In some cases, more triangles need to be created. The actual algorithm is up to the vendor.#footnote[I won't go into detail how this happens because the GPU does it entirely for us and nearly transparently. Basically, it's finding the edges that intersect the 6 planes of the clipping volume, cutting them to fit, and making new sets of triangles out of the new vertices.]
]

== The w-divide (aka "perspective divide")

What's the deal with that w-coordinate? 

In 3D graphics, we use a 4D coordinate system called homogenous coordinates. The reasons for this will be learned later in the course.

For now, think of "w" as being a "distance ratio". If w = 4 for a point, it means that it is "four times as far away" as for a point with w = 1.

Try experimenting with different w values for your triangle. If you set one vertex to have a w of 2, it will "push it back".

To achieve this effect, the GPU _divides_ x, y, and z by w. These new coordinates are called #strong[NDC]s (normalized device coorinates). 

== The w-divide (2)

The result of the w divide is that for all visible points, x and y will be in the range [-1, 1], z will be in the range [0, 1], and w won't be needed anymore.

This means, if you set w to 2 for all the points of a triangle, the result will be half the x and y, which will have the effect of making it twice as small.

z also gets shrunk, but you won't see the result on screen. You may have noticed that as long as z is in the range [0, w], it seems to have no effect on the triangle. The actual "perspective effect" does not happen automatically.

== The viewport transformation

The next step is to convert from NDCs to coordinates that are based on pixel locations.

So if a point is in the center of an 800 by 600 pixel screen, we'd like the point's coordinates to be (400, 300) instead of (0, 0).

To do this, we use a viewport, which is a volume that has whatever dimensions we set. Typically we set it to the resolution of our canvas.

To define a viewport, you give it the top left coordinates (usually 0, 0, but they don't have to be), the width and height, and the near and far values (which are almost always 0 and 1 unless you have niche needs).

== Viewport illustration 

#[
  #set text(size: 20pt)
#place(horizon + left, dx: 5%, dy: -2%,
box(width: 40%,
figure(
  numbering: none,
  alt: "a square representing the screen, with a point in the lower left corner",
  caption: "A point in NDC coordinates"
)[
  #canvas(length: 4cm,{
    import draw: *

    let tl = (-1,  1)
    let tr = ( 1,  1)
    let br = ( 1, -1)
    let bl = (-1, -1)

    set-viewport(bl, tr, bounds:(2, 2))

    line(tl, tr, br, bl, close: true)
    circle((-.5, -.5), radius: (0.02, 0.02))

    content((-1.3, 1), [(-1, 1)])
    content((1.3, -1), [(1, -1)])
    content((0,-.5), [(-0.5, -0.5)])

  })
]
))

#place(horizon + center,
box(width: 20%,
canvas(length: 1cm, {
  import draw: *
  
  let verts = (
    (0.5, 1),
    (1, 1),
    (1, 1.5),
    (1.5, .5),
    (1, -.5),
    (1, 0),
    (0.5, 0),
  )

  line(..verts, close: true)
})))

#place(horizon + right, dx:-5%, dy:5%,
box(width: 40%,
figure(
  numbering: none,
  alt: "a square representing the screen, with a point in the lower left corner",
  caption: [#set text(size: 18pt); The same point in viewpoint coordinates, in a viewpoint with a top-left of (100, 100) and dimensions of (200, 200)]
)[
  #canvas(length: 4cm,{
    import draw: *

    let tl = (-1,  1)
    let tr = ( 1,  1)
    let br = ( 1, -1)
    let bl = (-1, -1)

    set-viewport(bl, tr, bounds:(2, 2))

    line(tl, tr, br, bl, close: true)
    circle((-.5, -.5), radius: (0.02, 0.02))


    content((-1.3, 1), [(100,\ 100)])
    content((1.3, -1), [(300, \ 300)])
    content((0,-.5), [(150, 250)])
  })
]
))
]

== Viewport transformation

The viewport transformation can also be used to draw in multiple "sub windows" within your canvas.

For example, if you have an 800 by 600 canvas, you can 4 viewports which are 400 by 300. The top left would be at (0, 0). The top right would be at (400, 0). The bottom left would be at (0, 300). The bottom right would be at (400, 300).

Notice one thing in particular: the y axis goes in the opposite direction. Instead of y going up, it now goes down.

The reason for this is that old screens used to trace the pixels from top to bottom, right to left. It has become customary to use that order.

== Viewport transformation math

To perform the viewport transformation, you essentially convert a point into a percentage of width and height, scale by the width, and then add the top left coord.

That is, consider an x coordinate of -0.5 in NDC coords. That is _25%_ of the way between -1 and 1 (#math.equation(alt: "the numerator is negative zero point five minus negative 1, the denominator is one minus negative one. This simplifies to zero point five over two, which is 25 percent.", $(-0.5 - (-1)) / (1 - (-1)) = 0.5/2 = 25%$))

Now we scale by the width. If our viewport is 200 pixels wide, 25% is 50 pixels from the left of the viewport. Finally, we add the top left x value, which is 100, to get the final x coord, which is 150.

What about y? It's similar, but we compute its distance from the top. (see if you can match the computation of y in the illustration slide)

== Rasterization

So we transformed all our triangles to now use screen coordinates.

Why? Because now we're going to figure out which pixels are covered by each triangle.

This stage in the pipeline is called *rasterization*.

For each pixel in the screen, check its viewport coordinates.
If those coordinates are inside the triangle, run the fragment shader on it. #footnote[I'm oversimplifying a little. In reality, fragment shaders are normally grouped into 2x2 blocks for reasons to do with texture filtering.]

== Rasterization Illustration

#left-right()[
  #let fig = figure(
  numbering: none,
  alt: "A diagram that shows which pixels the fragment shader runs on.",
 canvas(length:10cm,{
  import draw: *;

  let rows = 10
  let cols = 10

  let verts = (
    (.1, .5),
    (.5, .15),
    (.9, .95),
  );

  // draw triangle
  draw.line(close: true, ..verts, fill:green)

  // draw grid lines
  for r in range(rows) {
    for c in range(cols) {
      draw.rect((c/cols, r/rows), ((c + 1)/cols, (r + 1)/rows))
    }
  }

  let cross(X, Y, Z) = {
    let bY = (Y.at(0) - X.at(0), Y.at(1) - X.at(1))
    let bZ = (Z.at(0) - X.at(0), Z.at(1) - X.at(1))
    bY.at(0) * bZ.at(1) - bY.at(1) * bZ.at(0)
  }

  let bary(p, a, b, c) = {
    let alpha = cross(b, c, p) / cross(b, c, a)
    let beta = cross(c, a, p) / cross(c, a, b)
    let gamma = cross(a, b, p) / cross(a, b, c)
    return (alpha, beta, gamma)
  }

  let pointInTri(p, tri) = {
    let (alpha, beta, gamma) = bary(p, tri.at(0), tri.at(1), tri.at(2))
    alpha >= 0 and beta >= 0 and gamma >= 0
  }

  // point grid
  for r in range(rows) {
    for c in range(cols) {
      let p = ((c + 0.5) / cols, (r + 0.5) / rows)
      let cw = 1/cols * 0.1
      let ch = 1/rows * 0.1
      if pointInTri(p, verts) {
        draw.circle(p, radius:(cw,ch), fill:blue)
      }
    }
  }
  })
)
#fig
][
  For each pixel, if the center of it is inside or touching the edge of the triangle, we run the fragment shader on it.

  If the pixel center is outside the triangle, we don't draw it.  

  #text(size: 20pt, [(This diagram is dynamic. Check the source code of this presentation to move the triangle around)])
]

== Barycentric coordinates

How do we know if a pixel is inside or outside a triangle?

Instead of cartesian coordinates, we can use *barycentric coordinates*.

The basic idea: take all the points on the surface of a triangle, and imaging that each one splits the original triangle into 3 sub-triangles.

Use the percentage of total area of each of the 3 sub triangles as the "point" instead of x,y.

So a point right in the middle of the triangle will always have barycentric coordinates of #math.equation(alt: "one third, one third, one third", $(1/3, 1/3, 1/3)$), regardless of how big the triangle is.

== Barycentric coordinates illustration

#left-right(left-width: 40%, right-width: 60%)[
  #image("screens/barycentric.png", height: 90%, alt: "Image illustrating Barycentric coordinates for points on a triangle.")
][
  #set text(size: 21pt)
  Each point's coordinates always add up to 100%.

  That's because the sub-triangles are split such that they cover the entire area of the whole triangle.

  Therefore, if that is _not_ the case, the point must not be on the triangle.
  
  See the source code in the illustration slide if you're curious about calculating them.

  #link("https://commons.wikimedia.org/w/index.php?curid=4842309", "Image by Rubybrian - Own work, CC BY-SA 3.0")
]

== Fragment Shaders

Once we know which pixels are visible and where they are on the screen, we finally invoke the fragment shader on each of them.#footnote[Another simplification. In realtiy, it's possible to do something called "multisampling", in which we run the fragment shader on sub-pixels.]

This means that typically the fragment shader gets run many more times than the vertex shader. 3 vertices can cover the entire screen.

The goal of the fragment shader? For each fragment, output its color.

Technically, it's possible for there to be multiple _attachments_. The fragment shader can write to any of them. Typically though, it returns a color.

== Output merging

Finally, those colors are written or merged into the canvas.

At the simplest, this is a giant blit: copy the pixel colors over.

In more complex cases, we might have to blend colors (e.g., in transparent rendering).

== Summary

So in summary, this is what we did:
- Issued a draw call
- The pipeline ran the vertex shader 3 times
- In the shader, we used the vertex id to look up and return a position
- A triangle was assembled from the 3 vertices.
- The triangle was clipped (which didn't do anything: it was all visible)
- The w-divide (which didn't do anything: w = 1 for our points)
- The viewport transformation was performed
- The triangle was rasterized: we learned which pixels were inside.
- The fragment shader executed on each pixel to get its color
- The pixel colors were copied to the canvas.

#focus-slide("Questions?")

== Next time


We stored our triangle coordinates inside the shader.

That's not good: it won't scale at all.

Don't worry: next time we'll learn how to store that information in a buffer inside the GPU.

This will be useful when we start loading meshes from files and drawing them into our 3D scene, or when we want to generate the mesh in code.

We don't want to have to have a custom shader every time we want a new mesh!

== The project

But first, let's take a look at the first project.

It's a simple one, designed to make sure you understood everything.

Instead of drawing a triangle: draw a quad. Specifically a rectangle.

And make sure you understand how to change its color.

(Let's take a look)

