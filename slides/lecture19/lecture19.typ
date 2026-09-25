#set document(title: "Notes on Computer Graphics: Lecture 19")

#import "@preview/touying:0.7.4": *
#import themes.simple: *
#import "@preview/shadowed:0.3.0": shadow
#import "../util.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/cetz:0.5.2" as cetz: canvas, draw

#show link: set text(blue)
#show: slide-theme


#title-slide[
  = Computer Graphics: Lecture 19
  == Terrain Engines

  \
  \
  \
  \
  Slide Deck © Grant Williams, 2026, License: #link("https://creativecommons.org/licenses/by-sa/4.0/deed.en")[CC-BY-SA 4.0] 
]


== Welcome back!

Last time we learned all about textures.

Before I summarize that huge lecture, [who can tell me about the texturing techniques we learned about?]

== Texture techniques

- We learned about MIP mapping [what is it?]
- We learned about trilinear filtering [ditto]
- We learned about anisotropic filtering [?]
- We learned about fragment quads and how the GPU selects MIP levels [?]
- Remind me: [what's a helper invokation]?
- We learned about multi-texturing [how does it work?]
- We learned about normal maps [ditto]
- We learned about specular maps, and just in general that we can put lookup tables in textures and call them "something maps"

== This time

This is a big one: we're going to use our knowledge to build a streaming, infinite terrain engine.

What is a terrain engine?

Well..

== Terrain Engines

#stack(dir: ltr, spacing: 5%,
  box(width: 45%, [
    Sometimes we want to display rolling terrain.

    This results in special requirements, but also special optimization opportunities.

    We call the part of our 3D engine that displays rolling terrain the "terrain engine".
  ]),

  box(width: 50%, [
    #image("screens/tribes2.jpg", alt: "a screenshot of the game Tribes 2")
    #place(bottom + right, dx: -1%, dy: -1%, game-name("Tribes 2"))
  ])
)

== Why would terrain be interesting?

#stack(dir: ltr, spacing: 5%,
  box(width: 45%, [
We've seen how to draw a 3D model. Why can't we just build a giant 3D model with all the terrain in it?

Well, we _could_ do that, but there would be a few problems...

[#link("https://www.gamedeveloper.com/programming/postmortem-dreamworks-interactive-s-i-trespasser-i-", [some ancient history about the game on the right])]
  ]),
  box(width: 50%, [
    #image("screens/trespasser.jpg", alt: "a screenshot of the game Jurassic Park: Trespasser")
    #place(bottom + left, dx: 2%, dy: -2%, game-name("Jurassic Park: Trespasser"))
  ])
)

== Problems with having terrain be a giant mesh

The first problem is the scale.

I looked outside the other day at the terrain, and I noticed that there was a lot of it.

If we place a quad every meter, a square kilometer is going to be roughly 2 million triangles.

This isn't actually unworkable. A modern GPU can draw 2 million triangles at 60 FPS reliably...

== Problems with having terrain be a giant mesh (2)

But a square kilometer isn't *that* much land. We can see Mt. Saint Helens clearly from campus and it's roughly 100 Km from campus.

If you want large, geologically significant terrain to be explorable in a 3D engine, you can't just draw a giant mesh.

Or rather, you can't just draw a giant mesh if you expect it to be dynamically generated based on your position. (If you know you'll be on campus, making a simplified mesh of the surrounding environment isn't too hard).

== Problems with having terrain be a giant mesh (3)

But let's say you want the following:
- Vast terrain area
- Randomly generated
- Streaming in as needed

In that case, you can't just create the terrain as a giant mesh.

In this lecture we're going to explore all these requirements and build a procedural terrain-engine that allows "infinite" areas of land to be streamed-in as the camera floats in any direction.

("infinite" in quotes because you run into floating point errors after a while)

#focus-slide("Questions?")

== Chunking the mesh

#stack(dir: ltr, spacing: 5%,
  box(width: 75%, [
Okay, step one, we aren't going to draw a giant mesh of terrain.

That means our terrain data will have to be broken up into *chunks*.

A chunk is a usually-cubic or rectangular-prismatic shaped mesh in which two of the axes (usually X and Z) are aligned with the world axes.

A popular example of this technique is a _Minecraft Chunk_ (shown right).
  ]),

  box(width: 20%, height: 80%, [
     #image("screens/minecraft-chunk.webp", alt: "a cross section of a vertical rectangular slice of Minecraft voxels.")
     #text(16pt, [#link("https://minecraft.fandom.com/wiki/Chunk?file=Chunk.png", "Source"): Cruxica, #link("https://creativecommons.org/licenses/by-nc/3.0/", [CC-BY-NC 3.0])])
  ])
)

== Benefits of chunks

The main benefit of breaking our terrain into chunks is that we don't have to have all of it loaded at any one time.

This is especially important when our terrain is infinite, which would be impossible.

But there are some other benefits too:
- We end up with a natural unit to do optimizations to, such as level of detail scaling or occlusion culling (we'll chat about these terms if there's time)
- We can cut down on loading times by not needing to load as much terrain data at scene start.

== Where does the chunk data come from?

We could technically model a terrain chunk in a 3D modelling program like Blender.

However, there is a simpler way to represent a chunk of terrain.

It's called a *heightmap*.

Recall from the textures lecture that texturing techniques often end with -map, and have the data stored in each texel before that.

That's the case here: a heightmap is a texture in which each texel stores the height of the land.

== Example heightmap

#image("screens/world-heightmap.png", height: 80%, alt: "a NASA heightmap of planet earth")

#link("https://www.earthdata.nasa.gov/topics/land-surface/digital-elevation-terrain-model-dem", "Source: NASA")

== Explaining it

Each pixel's brightness is interpretable as a height.

This particular heightmap doesn't include sub-oceanic heights, so the water is all 0 (minimum brightness). However, in the samples directory there's a world heightmap which includes even the depth under the ocean.

But what does it mean for each pixel to be a brightness? [Can we guess how we would turn image data like this into a mesh?]

== Pixel "heights"

One problem is that the brightness of a pixel does not really mean anything in terms of physical height.

We could interpet 100% brightness as 20 meters tall. Then our world heightmap would look rather flat. 

The image itself does not contain any dimensional information. You'd need to store that in meta-data or hardcode it.

And how much data do we have exactly? How is "brightness" encoded in a standard RGBA image?

== Pixel "heights" (2)

"Brightness" is a surprisingly subjective term. However, in the case of the heighmap I posted earlier, all 3 color channels have the same value for each pixel, and brightness is that value.

This means we effectively get 256 different heights. Not really a lot of precision for the whole world.

Some images use 16-bit color channels, which is better, but isn't really an ideal use of encoding space.

Can anyone think of another way to encode the heights of a grid in an image?

== Pixel "heights" (3)

Really, an RGBA 8-bit-per-channel image is just storing one 32-bit integer per pixel.

We can put whatever we want in it, including a 32-bit float.

32-bit floats are able to represent relatively precise height values for any place on earth. 

Ultimately, you have to do whatever the heightmap you're using does, so I just treated the brightness as interpolating evenly between the maximum and minimum values, but realize that you have a lot more flexibility than that if you want it.

#focus-slide("Questions?")

== Using a heightmap

There are basically two rather different, but straightforward ways to use a heightmap:
- We can bind it as a texture. We can make it available to our vertex shader, along with a flat grid mesh of vertices, and it can manually set the heights of each vertex by sampling the texture.
- We can use it to generate a mesh. Then, we're just drawing the mesh. This is a bit slower at first, because we typically generate the mesh with the CPU#footnote[It's possible to also use a compute shader to generate a mesh. This is cool, but a lot more complex.], but drawing it requires less work for the vertex shader.

== Heightmap as texture

We won't be using this approach, but I wanted to talk about it. It works like this:
+ Suppose your Grid Chunks are 64-by-64 cells (so 65-by-65 vertices). Create a 65-by-65 vertex mesh in which the XZ values are set according to the column and row in the mesh, and the Y values are 0.
+ Reuse this mesh for every terrain chunk. We're going to draw the same flat mesh over and over, but the vertex shader will change its Y values.
+ To draw a terrain chunk, send the mesh's local corner coordinates, and have the Y value come from the texture. Multiply the chunk by the model, view, etc. matrices.

== Heightmap as texture (2)

Basically, the idea here is that we pregenerate a mesh and store it in a buffer, and just reuse the same buffer over and over to save memory management.

Every time we go to draw that mesh, we sample the heights from a texture. We can use the vertex XZ values to compute the UV coordinates. We also probably don't want to use mipmapping.

This is a little slower than just having the height already be in the mesh, but the real downside is that things like normals are much slower to calculate. (We'll talk about how to do that, soon, but for now, it would require multiple samples and some vector math).

== Heightmap Interface

As a result, we'll be pre-calculating our heightmap chunks. This seems to be the most common technique from cursory investigation.

Let's design an interface for our heightmaps. This way, we can get our heightmap data from an image, or we can generate it procedurally, and we won't have to change our sampling code:

```ts
interface Heightmap {
    sample(row: number, col: number): number; 
} // sample is an abstract method, so there's no body.
```

[Do we remember what an interface is? It's fine if we need a reminder]

== Implementing it

Now we want to implement that interface. We will create a class `ImageHeightmap` that takes an image and samples it when the class's user calls `sample`.

#text(20pt)[
```ts
export class ImageHeightmap implements Heightmap {
    samples: number[][];
    rows: number;
    cols: number;
    
    constructor(img: ImageData, public amp: number) {
        this.rows = img.height;
        this.cols = img.width;
        this.samples = new Array(this.rows); 
        // ... more follows ...
```
]

== Implementing it (2)

We're storing samples in an array of arrays, so we can get the sample for location `20, 10` by indexing `samples[20][10]`.

Each sample is a height/brightness value for a particular coordinate.

`amp` is the amplitude. This is a very simple way of interpreting the height value from a brightness. We multiply brightness by the amplitude to get height.

This assumes that your minimum height is just the negation of your maximum height, but it works well enough for this simple case.

== Implementing it (3)

For `sample`, it would be really easy if the `row` and `col` that we sampled happened to be exact integers within the array.

Then we could just return `samples[row][col]`.

This is a reasonable assumption, but let's see what happens if we don't make it. Suppose we want to be able to smoothely interpolate between coordinates.

[Can anyone think of an algorithm?]

== Smooth interpolation

The simplest approach would probably be to use the bilinear filtering technique we learned about with textures.

There's a problem with it, however: it's linear interpolation.

Why is that bad?

Because the normal will not be defined at each grid coordinate.

[Why?]

== Smooth interpolation (2)

The issue is that with linear interpolation, there is a point or a kink at each sample. [we can whiteboard it]

With colors, we don't really notice or care, but with geometry, it is much more noticeable.

It's not the end of the world. We can estimate the normal by sampling a region around it, but let's see if we can solve this problem in a straightforward way.

We want to "stretch out" the region of space around the sample so that it's a little more flat, basically...

== Smoothstep

That brings us to the smoothstep function.

This is a function that transforms input coordinates. That is, it takes a row-col coordinate pair, and it outputs a new, smoother row-col pair.

How does it do that? With polynomial interpolation. 

```ts
// similar to AMD smoothstep from here:
// https://en.wikipedia.org/wiki/Smoothstep
function smoothstep(a: number, b: number, x: number): number{
    const xi = (x - a) / (b - a);
    const xc = xi < 0 ? 0 : xi > 1 ? 1 : xi;
    return xc * xc * (3.0 - 2.0 * xc);
}
```

== Smoothstep (2)

`xi` is the proportion that `x` is between the bounds `a` and `b`. For example, an `xi` of 0.5 would be halfway between them.

`xc` is the clamped verison of `xi`, so that it stays in the range `[0, 1]`.

The idea is that the polynomial in that sample, #math.equation($3x_c^2 - 2x_c^3$, alt: "three ex see squared minus two ex see cubed"), has a derivative of 0 at both `xc == 0` and `xc == 1`.Important note: we don't apply this function to the height values, we apply it to the _input coordinates_

== Smoothstep (3)

TODO

This is not the only polynomial with this property, and there are other polynomials, including those which have even higher derivatives of 0. Search for "smootherstep" for an example. These polynomials come from a technique called "Hermite interpolation", which is for finding interpolating polynomials whose derivatives agree to make the interpolation smooth.


