#set document(title: "Notes on Computer Graphics: Lecture 5")

#import "@preview/touying:0.7.4": *
#import themes.simple: *
#import "@preview/shadowed:0.3.0": shadow
#import "../util.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/cetz:0.5.2" as cetz: canvas, draw

#show link: set text(blue)
#show: slide-theme


#title-slide[
  = Computer Graphics: Lecture 5
  == Buffers and Colors

  \
  \
  \
  \
  Slide Deck © Grant Williams, 2026, License: #link("https://creativecommons.org/licenses/by-sa/4.0/deed.en")[CC-BY-SA 4.0] 
]

== Welcome Back!
Last time we drew a triangle!

It was kind of an adventure getting it to draw. 

But now that we've done that, we can just scale it up to drawing complex 3D models, right?

== Not so fast

Not quite. The way we did it (putting all the vertices in the shader) is not a way that will scale.

Instead, we want to store the vertices in an array in GPU memory, called a buffer. Then we want the vertex shader to read out of that.

Additionally, we want to add some color. The fragment shader is just drawing a solid color, which isn't very interesting.

== The Gameplan

First, we will modify our sample as follows:
- Change the shader to receive data from a buffer
- Create a buffer which stores the triangle data
- Tell the pipeline to get its data from a buffer
- Bind that buffer with a command so that it's there when needed.

Then we will learn how color works in detail. There is surprisingly a lot more to it than just RGB.

Finally, we will add some color to our mesh and have it smoothely blend between colors. That will be your next project!

== Vertex buffers

The main change we're going to make is to learn to use a vertex buffer.

A vertex buffer stores all the information each vertex needs.

What information is needed by a vertex? It's just a point in space...

Actually, we store tons of things in a vertex:
- Its position
- Its color
- Its texture coordinates (i.e., where on a detailed surface image this vertex's color comes from). This might replace the color info.
- Its normal (a vector pointing exactly away from the mesh)
- Potentially multiple texture coordinates, animation bones, etc.

== Vertex buffers (2)

The GPU is already set up to read from a vertex buffer, we just have to tell it that there will be one, and then make it available.

This means we need a somewhat more complicated pipeline.

It also means we need to create the buffer, and make sure we issue a command to load it.

The vertex shader will then receive its parameters from the buffer instead of using `vertex_index` to look them up in an array.

== Changing the shader

This is a shader that pulls its information from a vertex buffer:
```wgsl
@vertex fn vs(@location(0) vertPos: vec3f)
-> @builtin(position) vec4f
{
    return vec4f(vertPos, 1.0); // expand the 3D coord to 4D
}

@fragment fn fs() -> @location(0) vec4f {
    return vec4f(0.4, 0.8, 0.3, 1.0);
}
```

== What changed?

Previously, the input was `@builtin(vertex_index) index: u32`

Now, we write `@location(0) vertPos: vec3f`

When we use `@location(...)` in a parameter to the vertex shader, that argument will be extracted from a vertex buffer. In this case, from the 0th *attribute* (each piece of information in the vertex buffer is called an *attribute*) 

Note: the location in the fragment shader is _completely different_. The `@location(0)` it returns means that the result is written to the 0th attachment. It is a completely separate reference than the input to the vertex shader. It has nothing to do with vertex buffers.

== Now what?

Now, let's also create the data for a vertex buffer. We're going to use a special built-in Javascript type called `Float32Array`:

```ts
const vertData = new Float32Array([
    -.75, -.75, 0, // first vertex
     .75, -.75, 0, // second vertex
       0,  .75, 0, // third vertex
]);
```

This is a Javascript array where the elements are densely packed next to each other in memory (like an array in C, or a numpy array in Python).

Note: this _isn't_ on the GPU yet. This is a normal array in RAM.

== Creating a buffer on the GPU

Now we need to create a buffer on the GPU. The WebGPU driver will allocate the memory for us, but we need to tell it how much.

```ts
const vertBuf = device.createBuffer({
    size: vertData.byteLength,
    usage: GPUBufferUsage.VERTEX,
    label: "triangle vertex buffer",
    mappedAtCreation: true,
});
```

This creates a new buffer. Let's go over each of its fields...

== Buffer fields

First was `size`. This is the size in bytes. We have 9 floats, and each float is 4 bytes each, so we expect the buffer to be able to fit 36 bytes of data.

Then there's `usage`. This tells us how the buffer will be used. This is important because video drivers often store things differently in memory depending on how it will be used. In our case, we announce our intention to use this buffer as a vertex buffer.

The `label` is there for debugging. If we use our buffer incorrectly, it can tell us _which_ buffer was problematic.

Finally, theres `mappedAtCreation`...

== Memory Mapping

The GPU can have its own RAM separate from the CPU's RAM.#footnote[This isn't strictly required. In some systems the GPU shares memory with the CPU. This is called a "unified memory architecture". However, WebGPU is not built to assume that you have a unified memory architecture, because many systems don't. (integrated GPU systems usually do, discrete GPU systems usually don't)]

One of the fastest ways to write data to separate areas of RAM is to use a feature called *memory mapping*.

Memory mapping uses the memory controller on your CPU to make it so that when you write to a particular address, the bytes end up somewhere else.

`mappedAtCreation` means that WebGPU will map the buffer.

== Using the mapped buffer

The typed arrays, such as `Float32Array` have the ability to point to any memory area you choose. 

You can, e.g., have a buffer with 10 elements, and have two different `Float32Array`s pointing into it. They can point to the same elements or be offset.

To get the memory mapped address of the buffer we created, we call a method called `getMappedRange`.

We create a `Float32Array` that points into that range, and then copy the floats from our local data into the GPU...

== Using the mapped buffer example


