#set document(title: "Notes on Computer Graphics: Lecture 11")

#import "@preview/touying:0.7.4": *
#import themes.simple: *
#import "@preview/shadowed:0.3.0": shadow
#import "../util.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/cetz:0.5.2" as cetz: canvas, draw

#show link: set text(blue)
#show: slide-theme


#title-slide[
  = Computer Graphics: Lecture 13
  == Meshes, Topologies, and Indices

  \
  \
  \
  \
  Slide Deck © Grant Williams, 2026, License: #link("https://creativecommons.org/licenses/by-sa/4.0/deed.en")[CC-BY-SA 4.0] 
]


== Welcome back!

Last time, we learned about interactive cameras.

We learned how to move SceneNodes around.

We learned how to invert the camera's model matrix to make a view matrix.

We learned about Tait-Bryan/Euler angles, and the yaw-pitch-roll camera system. We also learned about alternatives.  

We learned how to read keyboard input.

We learned what a keycode is.

== This time

This lecture is all about meshes.

We've been using them the whole time, but we haven't really used them the way they get used in actual 3D engines.

So let's change that! We're going to make a mesh class, learn how to describe faces, and learn how to load meshes from a file.

== What is a mesh?

A mesh is a list of triangles representing an object's boundary surface.

The boundary surface is basically a surface that separates the inside of the object from the outside.

We've been learning all about meshes, because every thing we want to draw in 3D has a mesh.

Meshes are not the only way to draw objects. For example, voxel systems exist, where we sample points inside the region of space occupied by the object and draw those. But modern graphics systems usually convert even those into meshes anyway.

== What's in a mesh?

#stack(dir: ltr, spacing: 4%,
box(width: 48%)[
  A mesh contains a list of points.

  But not only that, or else it would be a point cloud. It also is a list of triangles.

  You've seen many meshes in your exposure to 3D graphics.

  Here's one in which the triangles are particularly visible.
],
box(width: 48%, height: 100%)[
  #place(center, dy: -2cm, image("screens/cloud_strife.png", width: 150%, alt: "a screenshot of Cloud Strife from Final Fantasy 7, 3-polygon hair-spike and all."))
  #place(bottom + right, dy: -15%, game-name([Final Fantasy VII], text-color: black))
]
)

== Meshes are important

Because a mesh represents something we want to draw, it is a super important concept. 

However, the way we've been drawing meshes is rather cumbersome. 

Specifically, we've been storing meshes as a list of vertices.

The triangles have been implicit. Every three vertices has been grouped together into a triangle.

This works, but it means we have to repeat a lot of vertices. Typically, a triangle will share an edge with another triangle, meaning two repeated vertices each time that happens.

== Indices

To streamline this, almost all the time a real 3D engine uses a mesh, or a 3D modelling program exports a mesh, it uses *indices*.

An *index* is an integer that refers to a vertex.

The mesh is then described by two pieces of information:
+ A list of vertices
+ A list of indices

Let's see a simple example...

== An indexed triangle

#stack(dir: ltr, spacing: 2%,
box(width: 70%)[
Here are some vertices that describe a triangle:
```ts
const vertData = new Float32Array([
  -.75, -.75, 0,
     0,  .75, 0,
   .75, -.75, 0,
]);
```


We can use indices too:
```ts
const indis = new Uint32Array([2, 1, 0])
```

This says "draw a triangle from points 2, 1, and 0" (which is important: 0, 1, 2 would be clockwise)
],
figure(
canvas(length: 2.5cm, {
  import draw: *;

  set-viewport((-1, -1), (1, 1))
  line((-.75, -.75), (0, .75), (.75, -.75), close: true)
  content((-.85, -.75), [0])
  content((0, .87), [1])
  content((.85, -.75), [2])
}),
alt: "An equilateral triangle, facing up, with lower left vertex labelled zero, top labelled 1, and lower right labelled 2."
)
)

== But why?

#stack(dir: ltr, spacing: 2%, 
box(width: 60%)[
Cool, we can take the thing we were already doing and now add 3 numbers to it. What's the point?

The point is that this ends up saving time and space when we have triangles that share edges.

For example, a quad: `[0, 1, 2, 0, 2, 3]`
],
figure(
canvas(length: 2.5cm, {
  import draw: *;

  set-viewport((-1, -1), (1, 1))
  line((-1, -1), (-1, 1), (1, 1), (1, -1), close: true)
  content((-.9, -.9), [0])
  content((.9, -.9), [1])
  content((.9, .9), [2])
  content((-.9, .9), [3])
}),
alt: "A quad with its vertices labelled 0, 1, 2, 3 starting from the lower left and going counter clockwise"
)
)

== The quad

Notice: before when we wanted a quad, we needed to specify 6 vertices.

That means 6 positions, not to mention all the other attributes (6 colors, 6 uv-coordinates, in the future 6 vertex normals).

Now we only need 4, and then an index buffer of integers.

The indices can get grouped together in groups of 3 like before, so we draw the triangle 0, 1, 2, and then the triangle 0, 2, 3.

There are other ways to group indices, which we will discuss soon.

What if we made a cube?

== The cube

We can define a cube with 8 vertices.

How many indices does it take? At maximum, it would take 36. Each face of the cube has 2 triangles, so that's 6 indices per face, and there are 6 faces. Much nicer than needing 36 vertices.

#figure(image("screens/cube.png", alt: "an image of a cube"))

== The cube (2)

Just be aware, this cube only needs 8 vertices, but others might need more. 

For example, if you had a separate piece of texture on each side of the cube, you would need to duplicate vertices to give new UV coordinates to each face.

You can only share vertices if all the data (including all the attributes, and not just position) is exactly the same.

Luckily, most of the time, it actually is.

== More complicated meshes

A more complex mesh can really save a lot of space using index lists.

The GPU is designed to work with them efficiently.

In fact, we can get much more efficient than you've seen, using different *topologies*, but that will come soon. 

So, hopefully you're sold on index buffer's usefulness.

#focus-slide("Questions?")

== Drawing a mesh _without_ indices

Previously, here is how we drew a simple mesh:
+ Create a vertex buffer and load it with the mesh's data
+ Create a shader module that is compatible with the vertex data.
+ Create a pipeline, and reference the shader module and attributes.
+ Create a command encoder and a pass.
+ Set the pipeline and vertex buffer.
+ Draw

== Drawing a mesh _with_ indices

To use indices, there are a few things we need to adjust:

- In addition to the vertex buffer, we also create an index buffer. It is a buffer with `GPUBufferUsage.INDEX` instead of `.VERTEX`. We use integer data, so instead of `Float32Array` we use `Uint32Array` as the source data.
- In the pass, we don't only set the vertex buffer. We also set the index buffer: `pass.setIndexBuffer(indexBuffer, 'uint32');` The `uint32` is there because some index buffers use smaller `uint16`s to save space.
- When we draw, we use `pass.drawIndexed(indexCount);` instead of regular `pass.draw(vertexCount)`.

== That's all

You might think there would need to be more. Adjusting the shaders, more pipeline configuration, bind group stuff, but no, that's it.

We add an additional buffer for the indices, we set it, and then use a different method to draw.

Just to be clear: you don't need to mess with the shaders at all. They don't know whether they are being called on indices or vertices. The vertex shader still gets the vertex data. The primitive assembly system still constructs triangles for the fragment shader to interpolate over.

However, the vertex shader can be called fewer times now. It won't need to be called on duplicate vertices.

== The sample 

Let's look at the sample to see an example.

Notice, there is a spinning cube and...is that a teapot?

#image("screens/sample.png", height: 50%, alt: "a cube floating over a teapot.")

(don't mind the colors for the teapot, I'm generating them randomly)

== The mesh classes

Two items of interest: there are two mesh classes.

One of them is for describing a mesh (its colors, positions, and indices):
```ts
export class SimpleMesh {
    indices: number[];
    positions: vec3[];
    colors: vec3[]; // we could add more attributes easily
    nVerts: number;
    topology: GPUPrimitiveTopology; // (covered soon)
    stride: number = 6 * 4; // 3 position floats, 3 colors
    name: string;
    ...
}
   
```

== The mesh classes (2)

The second class stores the info needed to _draw_ the mesh. That is, the data on the GPU itself, after the mesh is loaded.

```ts
class LoadedSimpleMesh {
    vertexBuffer: GPUBuffer;
    indexBuffer: GPUBuffer;
    nVerts: number;
    nIndis: number;
    topology: GPUPrimitiveTopology;
    ...
}
```

== The mesh classes (3)

These classes are useful because they group together the two buffers we're going to need: vertex and index.

They also keep track of how much data is in them: something we used to hardcode.

But what's that topology thing?

== Topologies

The topology describes how the indices group vertices together.

The default topology is `"triangle-list"`, which means that we're describing a list of triangles, three vertices at a time.

Technically there are also options for lines (useful for wire-frame debuggging) and points (for point clouds).

But there's another option, called `"triangle-strip"`...

== Triangle strips

The vast majority of the time, the triangles are not independent. Instead, they usually are tesselating a larger figure, meaning a bunch of triangles are sharing edges.

It's wasteful to describe a triangle that shares an edge with another triangle. We end up specifying the vertices multiple times.

For example, instead of the triangle list `[0, 1, 2, 2, 0, 3]`, we could describe it as a triangle strip: `[0, 1, 2, 3]`...

== Triangle strips (2)

#figure(
  canvas(length: 2cm, {
    import draw: *;
    
    set-viewport((-1, -1), (1, 1))

    line((-1, -1), (-1, 1), (1, 1), (1, -1), close: true)
    content((-1.1,  1.1), [0])
    content((-1.1, -1.1), [1])
    content(( 1.1,  1.1), [2])
    content(( 1.1, -1.1), [3])

    line((-.9,  .9), (-.9, -.9), stroke:(dash: "dashed"), mark: (end: "straight"))
    line((-.9, -.9), ( .9, .9), stroke:(dash: "dashed"), mark: (end: "straight"))
    line(( .9,  .9), ( .9,-.9), stroke:(dash: "dashed"), mark: (end: "straight"))

    content((-.25, .55), [[0, 1, 2]])
    content((.35, -.4), [[1, 2, 3]])
  }),
  numbering: none,
  caption: [A quad drawn from the triangle strip [0, 1, 2, 3]],
  alt: "The top left is vertex 0, the bottom left is 1, the top right is 2, and the bottom right is 3. The strip [0, 1, 2, 3] creates two triangles, [0, 1, 2], and [1, 2, 3].",
)

== Triangle strips (3)

When the GPU encounters a triangle, it forms a triangle from the first three indices. In the previous slide that was [0, 1, 2].

Then, every index that follows shares the edge from the previous two indices. So the 3 ends up being linked with the 1, 2: [1, 2, 3]

What about winding order, though? [0, 1, 2] is counter-clockwise, but [1, 2, 3] is clockwise.

Don't worry, the GPU handles that. Every other triangle in a strip has its winding order inverted. So it just knows that the [1, 2, 3] should be facing the same way as [0, 1, 2].

== Triangle strips (4)

There's no reason we have to stop at a quad. We can draw a whole ribben of indices in a triangle strip, approaching a two-thirds index savings...

#figure(image("screens/Triangle_Strip.svg", height: 50%, alt: "a triangle strip that forms 4 triangles with only 6 indices"), numbering: none, caption: [a clockwise strip: [A, B, C, D, E, F]])

== Drawing more than a ribbon...

In fact, drawing ribbons is the main point. It's a "strip" after all.

But what happens when we reach the end of a ribbon?

For example, suppose we want to draw an extremely common shape: a cube. Let's try drawing it as a triangle strip...


== Attempting a triangle-strip cube

Here are 8 vertices:

#figure(
  canvas(length: 1cm, {
    import draw: *;

    set-viewport((-1, -1, -1), (1, 1, 1))

    perspective(y: 55deg, {
      circle((-1, -1, -1), radius: 0.03)
      circle((-1, -1,  1), radius: 0.05)
      circle((-1,  1, -1), radius: 0.05)
      circle((-1,  1,  1), radius: 0.05)
      circle(( 1, -1, -1), radius: 0.05)
      circle(( 1, -1,  1), radius: 0.05)
      circle(( 1,  1, -1), radius: 0.05)
      circle(( 1,  1,  1), radius: 0.05)

      content((-1, -1.3, -1), text(20pt)[0])
      content((-1.1, -1, 1.2), [1])
      content((-1, 1.4, -1), [2])
      content((-1.4, 1, 1), [3])
      content((1.4, -1, -1), [4])
      content((.7, -1, .7), [5])
      content((1.1, 1, -1.3), [6])
      content((1, 1.3, 1), [7])
    })
  }),
  numbering: none,
  alt: "8 vertices forming a cube in perspective. The top face has indices 3, 2, 7, and 6 in clockwise order. The corresponding vertices on the bottom are 1, 0, 5, and 4.",
)

Make me a cube with a triangle strip! The indices don't have to go in order! But be sure the winding is correct.

== It's actually possible...

#image("screens/cube_strip.png", height: 60%, alt: "the cube in the previous slide annotated with the lines forming the following triangle strip.")

The strip is: [6, 2, 4, 0, 1, 2, 3, 6, 7, 4, 5, 1, 7, 3]

Credit to #link("https://www.cs.umd.edu/gvil/papers/av_ts.pdf", [this paper]) and #link("https://stackoverflow.com/questions/28375338/cube-using-single-gl-triangle-strip", [this stackoverflow])

== ...but it's hard

When you need to look up a research article to tesselate the cube, you might get a bit discouraged.

And for some meshes it's _actually_ impossible. For example, meshes that are disconnected. There's literally no way to do it.

Luckily, there's a useful feature: *primitive restart*.

It's a special index, equal to the largest integer supported by your index size. If you're using `Uint16`s, then it's `0xFFFF`. If you're using `Uint32`s, it's `0xFFFFFFFF`.

When the GPU sees that, it _snips_ (restarts) the triangle strip.

== Restarted cube


#image("screens/cube_strip_restart.png", height: 60%, alt: "the cube in the previous slide annotated with the lines forming the following triangle strip.")

The strip is: [5, 7, 1, 3, 0, 2, 4, 6, 5, 7, `0xFFFF`, 3, 7, 2, 6, `0xFFFF`, 5, 1, 4, 0]

I left out the top and bottom faces in the drawing, but you can see them after the primitive restart indices (`0xFFFF`s).

== Not as good?

This strip isn't quite as optimized. It ends up requiring more indices.

But it's a bit easier to understand.

To see a similar strip in action, look at `simpleCubeMesh()` in `sample10`.

== Using triangle strips

So, is there anything we need to change to use triangle-strips? How does WebGPU know our topology?

Look at the `primitive` field of the pipeline descriptor:
#[
#set text(20pt)
```ts
primitive: {
    cullMode: 'back',
    frontFace: 'ccw',
    topology: 'triangle-strip',
    stripIndexFormat: 'uint16',
}
```
]

We changed the topolgy and also told it what kind of integer will be used. The only options are `"uint16"` and `"uint32"`.

== Anything else?

That's it. Your existing index-buffer will work, you'll just store a strip in it instead.

If you use `uint32`, the restart index is `0xFFFFFFFF` instead.

That's all for now regarding topologies. For the next part, we're going to go back to normal triangle lists. But we _will_ be using index buffers pretty much from now on.

#focus-slide("Questions")

== The teapot

#stack(dir: ltr, spacing: 4%,
box(width: 48%)[
Okay, what's the deal with the teapot?

It's the #link("https://en.wikipedia.org/wiki/Utah_teapot", "Utah Teapot"), named after the University of Utah where the early computer graphics researcher Martin Newell painstakingly derived the bezier curves of a Melitta brand teapot.

It's a computer graphics in-joke now, and is often a test model.
],
image("screens/utah_teapot_graph_paper.jpg", height: 85%, alt: "A graph-paper sketch of the key vertices of the teapot.")
)

== The teapot (2)

The teapot is a _real_ mesh. Not a cube or a triangle, but an actual boundary surface of a 3D object.

But how do we draw it? There's no `pass.drawTeapot()` method in WebGPU. #link("https://en.wikipedia.org/wiki/File:The_Six_Platonic_Solids.png", [Though maybe there should be]). #footnote[You might think I'm joking but some graphics libraries literally have a draw teapot function. It's that popular. It's useful to test lighting.]
