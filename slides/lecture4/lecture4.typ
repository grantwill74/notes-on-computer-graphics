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

WGLS must know where every variable comes from. Saying `@builtin(vertex_index)` means that the parameter will come from the built-in index value of the vertex.

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

== Let's learn the pipeline now

There are two things that are missing from our understanding so far:
+ The pipeline has a lot of implicit stages. How are those coordinates interpreted? How does the system know how to fill in the triangle?
+ We do not want to hardcode the coordinates of the triangle in the shader. One shader is often useful for many objects. The memory available inside the shader is quite limited. We want to store the triangle in a buffer instead.

== Fragment Shaders

#let fig = figure(
  numbering: none,
  alt: "A diagram that shows which pixels the fragment shader runs on.",
 canvas(length:10cm,{
  import draw: *

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

#left-right(fig)[
  todo: Explanation
]