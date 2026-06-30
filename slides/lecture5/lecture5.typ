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

```ts
// this guy is now pointing at some memory that will 
// be copied into the GPU and overwrite the buffer.
const mapped = new Float32Array(vertBuf.getMappedRange());
mapped.set(vertData); // .set(...) performs this copy
```

Since we're only using the second `Float32Array` once to copy some data over, we can combine creating it and setting its data like this:

```ts
(new Float32Array(vertBuf.getMappedRange())).set(vertData);
```

When done, it's very important to unmap it:
```ts
vertBuf.unmap();
```

#focus-slide("Questions?")

Now we have a buffer, but our pipeline needs to know that a buffer will exist when we draw next time. The changed part is the `vertex` field:

#[
  #set text(20pt)
```ts
vertex: {
  module: shaderMod,
  buffers: [{
      attributes: [{
          format: "float32x3",
          offset: 0,
          shaderLocation: 0,
      }],
      arrayStride: 3 * 4,
  }]
},
```
]

== Explaining the fields

Every piece of information we associate with a vertex in the vertex data is called a *vertex attribute*.

Right now we have 1 attribute: position.

Soon we will have a 2nd one: color

Each attribute has a location. We coded our shader to assume that `@location(0)` was the vertex's position, so we use `shaderLocation: 0`

The format is the datatype. Here, `float32x3` means a vector of 3 floats.

Offset is the number of bytes into the buffer of the first vector of that attribute. Ours has no data before it, so use `0`.

== What is "stride"?

Stride is a bit confusing.

It's the number of bytes _between_ two instances of the same attribute.

So its the number of bytes between each `position`.

Since each position is 3 floats, and each float is 4 bytes, there are 12 bytes between each position.

The GPU will use the offset to find the attribute of the first vertex, then multiply the stride by the vertex index. This regular storage layout allows the GPU to process vertex it needs at any time in constant time without having to search through a linked list or something.

== Using the buffer?

So, we made a buffer and loaded it with data. Our pipeline is expecting there to be a buffer. How do we actually use it?

We have to *bind* the buffer. Meaning, we tell WebGPU that there is a buffer at buffer location `0`. 

Why zero? Because in our pipeline description, we only have one buffer, and it's the zeroth element in our array. We could have many buffers, one for each attribute, and we would then need to bind them all.

#[
  #set text(size: 16pt)
```ts
  // from the pipeline description
  buffers: [{ // <- notice that `buffers` is an array of objects.
    // ... there could have been more than one buffer.
  }]
```
]

== Using the buffer (2)

But for us, we told our pipeline to expect 1 buffer with the 1 attribute:
```ts
pass.setVertexBuffer(0, vertBuf);
```

We're saying: "set the zeroth buffer to use `vertBuf`"

Note, we use the buffer on the GPU that we created with `device.createBuffer(...)`. We don't use a `Float32Array`.

The buffer object is basically a pointer or handle to some GPU memory.

Then we draw like normal:
```ts
pass.draw(3); // everything else is the same
```

== What do you see?

#image("screens/triangle.png", alt: "a screenshot of a green triangle.", height: 60%)

Hopefully the same thing. If not, let's debug!

#focus-slide("Questions?")

== Adding colors 

Now it's time to understand colors better.

What is there to understand? Quite a lot actually.

Did you know that most people can see a lot more colors than your screen can show?

Or that some screens actually have wider ranges of colors they can display, and that you can actually choose which color profile you use when creating your canvas context?

Read on!

== Why do we use RGB?

We've been using RGB (red/green/blue) to describe colors.

Why don't we use some other colors as our basis, like "gray, periwinkle, burnt-umber" or something?

[What's so special about RGB?]


== Light

It has to do with how our eye responds to light.

What even is light?

It's electromagnetic radiation in a particular range of wavelengths that a typical eye can respond to.

The kind of light we're interested in in this course is the kind most humans perceive. 

== How eyes typically respond to light

#place(bottom + center,
figure(
  numbering: none,
  caption: text(size: 16pt, [#link("https://en.wikipedia.org/wiki/File:Cone-fundamentals-with-srgb-spectrum.svg", [Image source]), generated from cone sensitivity data from #link("http://cvrl.ucl.ac.uk/cones.htm", "here").]),
image("screens/cone_response.png", height: 75%)
)
)

== How eyes typically respond to light (2)

A typical human eye has many instances of three types of color cones spread throughout the surface of the retina. 

The three types of cones are named after the wavelength of light they react most strongly to. *S* cones react to short wavelengths (blues and purples), *M* cones react mainly to green, and *L* cones mainly to yellow.

It's fuzzy though. You might have thought that one kind of cone _only_ reacted to red, and another _only_ to green. They bleed into each other, and not everyone's eyes react the same.

== How eyes typically respond to light (3)

Some sighted people do not experience as much response from one or more of the kinds of cones.

These condition is called _colorblindness_. When making graphical software, be aware that some people experience colors differently. #footnote[I've tried to ensure this course and the assignments are colorblind accessible. If you have colorblindness and believe it will hinder you from completing an assignment, please let me and the access center know so that we can modify the course.]

Rarely, some people may possess 4 cones. They are called #link("https://en.wikipedia.org/wiki/Tetrachromacy", "Tetrachromats"), althought this seems to have only been demonstrated once under scientific conditions. The fourth cone's response function was between the M and L cones.

== This raises a question

Here's the first question that might pop up after looking at that graph:

"Why isn't color a one-dimensional value"?

After all, if the color is one dimensional, and our cones react to different wavelengths, why not just store the color itself? Why store how much each wavelength is present?

#image("screens/spectrum.webp", alt: "the color spectrum")

== Because lights can be added together


