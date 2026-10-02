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

"Brightness" is a surprisingly subjective term. However, in the case of the heightmap I posted earlier, all 3 color channels have the same value for each pixel, and brightness is that value.

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

The idea is that the polynomial in that sample, #math.equation($3x_c^2 - 2x_c^3$, alt: "three ex see squared minus two ex see cubed"), has a derivative of 0 at both `xc == 0` and `xc == 1`.

We apply this function to the _input coordinates_. This causes the coordinate to approach `a` or `b` slower than it normally would when it is close, and ensures that the derivative is defined.

== Smoothstep (3)

This is not the only polynomial with this property.

There are other polynomials, including those which have even higher derivatives of 0.

These polynomials come from a technique called "Hermite interpolation", which is for finding interpolating polynomials whose derivatives agree to make the interpolation smooth.

See #link("https://en.wikipedia.org/wiki/Smoothstep#Origin", "this explanation") to see how the math is used to solve for the polynomials. The 5th-degree polynomial version is called "smootherstep". It has the second derivatives also being 0.

#focus-slide("Questions?")

== Back to the image heightmap

Since we want to sample smoothly, let's break our procedure into pieces to make sure we understand all the steps:
+ First, we'll clamp the coordinates we want to sample to make sure they're in range. We could also repeat them. Or repeat one dimension and clamp another (useful for world maps).
+ Then, we'll pull the top-left, top-right, bottom-left, and bottom-right height pixels that are closest to the sample point. Exactly like how textures get bilinearly-filtered.
+ We apply `smoothstep` to our sample coordinates.
+ We do bilinear interpolation with the resulting smooth coordinates.

== Sampling an image heightmap: clamping coordinates

Clamping is straightforward:
#text(22pt)[
```ts
const topR = Math.max(Math.min(Math.floor(row), this.rows - 1), 0);
const botR = Math.max(Math.min(Math.ceil(row), this.rows - 1), 0);
const leftC = Math.max(Math.min(Math.floor(col), this.cols - 1), 0);
const rightC = Math.max(Math.min(Math.ceil(col), this.cols - 1), 0);
```
]

For rows: compute the row below the coordinate and above. Make sure both are clamped to be in bounds. Do the same to columns.


== Sampling an image heightmap: grabbing the corners

Now we need the top-left, top-right, etc. We compute those from the 4 variables we created in the last slide.

#text(22pt)[
```ts
const tl = this.samples[topR]![leftC]!;
const tr = this.samples[topR]![rightC]!;
const bl = this.samples[botR]![leftC]!;
const br = this.samples[botR]![rightC]!;
```
]

Note, we're using the `!` operator, which is a typescript operator that asserts that the value is defined. Normally an array index can be undefined. We're saying "I promise this is not undefined." This promise is justified because of the clamping we did.

== Sampling an image heightmap: `smoothstep`

Now we use smoothstep to make the sample coordinates vary smoothly between 0 and 1:

```ts
const alphaHoriz = smoothstep(0, 1, col - leftC);
const alphaVert = smoothstep(0, 1, row - topR);
```

We're taking the given column and row coordinates and interpolating them to be between 0 and 1, but approaching 0 and 1 more slowly as they get closer (i.e., the derivative of `smoothstep` approaches zero).

== Sampling an image heightmap: bilinear interpolation

Lastly, we do linear interpolation between the two top samples, then linear interpolation between the interpolated results.
#text(21pt)[ 
```ts
const sampHoriz1 = tl * (1 - alphaHoriz) + tr * alphaHoriz;
const sampHoriz2 = bl * (1 - alphaHoriz) + br * alphaHoriz;
const sampVert = sampHoriz1 * (1 - alphaVert) + sampHoriz2 * alphaVert;

return sampVert;
```
]

This is bilinear interpolation. The same thing that happens when your GPU samples a texture in `"linear"` mode.

== What about normals?

We don't just want to know how heigh a point is, we also want to know which direction it's facing (i.e., its normal).

Partly for lighting purposes, but also, we're going to learn a texture sampling technique that is an alternative to storing UV coordinates in the mesh, and it requires a normal.

So, how can we compute or estimate the normal in a heightmap?

[thoughts?]

== Estimating normals

We've actually done it before, in the advanced textures lecture.

When we had a cube-map wrapped around a sphere, we had the normal already, and we used it to compute the tangent and bitangent.

This time, we don't have the normal, but we can compute the tangent and bitangent.

The normal is the cross product between those two vectors.

== Estimating normals (2)

Let's define a function to compute it

```ts
function heightmapSampleNormal(
    h: Heightmap, row: number, col: number,
): vec3 { ... }
```

Within this function, we're going to take one of our generic heightmaps (which could be an image or some random terrain) and a location to compute the normal for.

Here, we have a parameter of type `Heightmap`, which is an interface.

== Estimating normals(3)

First, we compute the tangent vector.

Recall that the normal points "out away from" the surface at a point. The tangent and bitangent vectors point "sideways", in the direction the surface is curving.

There are actually infinitely many tangent vectors. They can point in any direction, as long as it is orthogonal to the normal.

So, we need to pick one. The simplest to pick is to just have it point in the X direction.

== Estimating normals (4)

So, sample the height of our left and right neighbors, and have the tangent be pointing between them.

```ts
const leftNeigh: vec3 = [-1, h.sample(row, col - 1), 0];
const rightNeigh: vec3 = [1, h.sample(row, col + 1), 0];
const tan = vec3.create();

vec3.sub(tan, rightNeigh, leftNeigh);
vec3.scale(tan, tan, 0.5); // before this, it has length 2
```

The tangent here is basically acting as the slope between the left and right sample around (row, col).

== Estimating normals (5)

The bitangent calculation is similar, but we use the top and bottom neighbors instead.

When we're done, the normal is estimated as being the cross product of the tangent and bitangent.

```ts
const normal = vec3.create();
vec3.cross(normal, bit, tan);
vec3.normalize(normal, normal);

return normal;
```

#focus-slide("Questions?")

== After sampling: building a Chunk

Okay, we have an `ImageHeightmap` class. It represents an image that can be loaded from a file, whose pixel brightnesses are interpreted as heights. We can sample it smoothly anywhere.

Now we need to turn it into a mesh. We can call a mesh a _Chunk_.

Remind me, [what goes into a *mesh*]?

== Building a chunk

Meshes are typically composed of two arrays:
- *Vertices*, which themselves are composed of *attributes*.
- *Indices*, which tell us how to form the triangles.

In addition, a mesh can have a *topology*, which tells us how to interpret the indices.

Remind me, [what are the topologies we have learned]?

== Mesh topologies

The two most important topologies are triangle lists and triangle strips.

A triangle list treats the index array as an array of triples, each of which describes the three vertices that make up a triangle.

A triangle strip is an optimization on triangle lists. It assumes that the first three indices form a triangle, and each index is a triangle formed from the previous two.

For example, the strip `1 2 3 4 5 6` turns into the triangle list `1 2 3`; `2 3 4`; `3 4 5`; `4 5 6`.

== Triangle Strips

Triangle strips are usually a wonderful optimization: not only do they remove a chunk of bus bandwidth needed to send meshes to the GPU, they can also make it easier to generate meshes to begin with.

Especially meshes that are naturally composed of strips.

Do you see where I'm going with this? Suppose we have a grid of heights. Can you think of how we could use triangle strips to construct a mesh that has those same heights?

== Terrain Chunk example

Suppose this is a grid of heights that we're looking at from the top down. So the horizontal axis is X, and the vertical axis is Z.


#figure(
  canvas({
    import draw: *;
    set-viewport((0, 0), (1, 1), bounds: (1, -1))
    for row in range(5) {
      for col in range(5) {
        circle((col, row), radius: .1);
      }
    }
  }),
  alt: "A 5-by-5 grid of points",
  numbering: none,
  caption: [Each point represents a different height value. We're viewing the terrain from the top down.]
)

Assume that each point is numbered left to right, top to bottom, starting at 0 for the top left.

== Terrain chunk example (2)

Let's form a single square of terrain like this:


#figure(
  canvas({
    import draw: *;
    
    set-viewport((0, 0), (1, 1), bounds: (1, -1))
    for row in range(5) {
      for col in range(5) {
        circle((col, row), radius: .1);
      }
    }
    line((0, 0), (0, 1), (1, 0), (1, 1))
  }),
  alt: "A 5-by-5 grid of points in which the top left point is connected to its lower neighbor, the lower neighbor is connected to the second point in the top row, and that point is connected to its lower neighbor.",
)

To construct this quad, we would create the triangle strip:
`0 5 1 6`. Note: this is probably not a planar quad! The corners can all have different heights.

The vertices along the top row are numbered from `0` to `4`, so `5` is the first vertex in the second from row from the top.

== Terrain chunk example (3)

Keep going until we have the entire top row of terrain...

#figure(
  canvas({
    import draw: *;
    
    set-viewport((0, 0), (1, 1), bounds: (1, -1))
    for row in range(5) {
      for col in range(5) {
        circle((col, row), radius: .1);
      }
    }
    line((0, 0), (0, 1), (1, 0), (1, 1), (2, 0), (2, 1), (3, 0), (3, 1), (4, 0), (4, 1))
  }),
  alt: "A 5-by-5 grid of points in which the top left point is connected to its lower neighbor, the lower neighbor is connected to the second point in the top row, and that point is connected to its lower neighbor.",
)

At this point, we have described a horizontal strip of terrain. `0 5 1 6 2 7, ...`, etc. It's a little awkward to keep the strip going after the top row. We would have to have a degenerate triangle along the right side.

Instead, what do we do to cut off a triangle strip?

== Primitive restart

We "snip" the triangle strip after the last triangle of the row by putting in the special *primitive-restart* value at the end of the strip.

This value is `0xFFFF` for 16-bit vertex indices, and `0xFFFFFFFF` for 32-bit indices (I'm using 32-bit ones in the sample).

So, a triangle strip describing the top row is as follows:
`0 5 1 6 2 7 3 8 4 9 0xFFFFFFFF`

So, my next question: [what is the next row]?

All the rows will go in the same triangle strip, so we can draw the whole terrain chunk with a single call.

#focus-slide("Questions?")

== Describing the vertices

Of course, the index list is only half of the mesh.

The other half is its vertices.

When we want to create a mesh, we have to ask the question: what attributes do I want?

[So, what do you think?]

== Describing the vertices (2)

We certainly need position.

We also need a normal.

You might think "UV", and that's a reasonable thought. However, if our terrain has a repeating texture, we can actually use the X and Z coordinates instead of UV (although if you want to paint specific parts of a texture onto specific areas of terrain, you still need UV).

Interestingly, we could also store the "amount" of different kinds of texture as an attribute. Like "grassiness", "sandiness", etc. I didn't end up doing this, but it's worth a look if you need ideas for your final project!

== Describing the vertices (3)

So position and normal is actually all we need.

We saw how to sample these earlier.

Therefore, we can construct a  terrain chunk as follows:
- Iterate over each vertex: its `row` is the `Z` coordinate, its `col` is the `X` coordinate, and its sampled height is the `Y` coordinate.
- Use the algorithm we discussed earlier to estimate its normals.
- Push the position and normal into a vertex data array
- Iterate over each row, add indices to an index array in the `i (i + rowLength) (i + 1) (i + rowLength + 1)` pattern we saw.
- Create buffers and a bind group for these data.

== What about shaders?

For now, let's keep it simple. Let's just make the terrain be a flat green color, and we'll make it be darker the further down it is.

The terrain shader is very easy to describe. Just the standard view, proj, model calculation from before, and we pass through the position and normal.

We could technically do our color calculation in the vertex shader, but later we're going to replace it with texturing, so let's do it in the fragment shader so we won't have to refactor as much later.

== What about shaders? (2)

Earlier, we scaled our heightmap by a constant factor as a way to interpret our brightness values as actual heights.

Let's say that we scale it so that -5 is the minimum height, and 5 is the maximum (i.e., an amplitude of 5). How can we make it so that the grass color is linearly interpolated between these two values?

Imagine that our heightmap is interpreting brightness like: \ `(pixel.r / 255 - 0.5) * amp`.

[class]?


== Is that all?

It's not ideal for infinite terrain, but if we're using a heightmap, we can just load the whole thing into a single mesh and call it a day.

We might still want to chunk it, depending on the terrain complexity and whether we need to use culling or level of detail techniques, but for now, let's see what happens if we just draw our terrain chunk we loaded...

There's actually a built in WGSL function for doing linear interpolation named #link("https://webgpufundamentals.org/webgpu/lessons/webgpu-wgsl-function-reference.html#func-mix", [`mix`]), which takes two extreme values and a "blend-amount" parameter.

== Simple linear color blending

Suppose we want the minimum and maximum colors to be as follows:
```wgsl
const MIN_COLOR: vec3 = vec3(0.1, 0.1, 0.1);
const MAX_COLOR: vec3 = vec3(0.1, 0.9, 0.1);
const MIN_HEIGHT: f32 = -5.0;
const MAX_HEIGHT: f32 = 5.0;
```

We know the heights will be between -5 and 5. We want to know how far a given height is within that region. That is, we want 0 to be 50%, 5 to be 100%, and -5 to be 0.

== Simple linear color blending (2)

The calculation works like this:
```wgsl
let alpha = (height - MIN_HEIGHT) / (MAX_HEIGHT - MIN_HEIGHT);
```

We call that value "alpha". Now we can call mix to get the color:
```wgsl
let color = mix(MIN_COLOR, MAX_COLOR, alpha);
```

You could also just do the linear interpolation yourself, which is what `mix` does for you:
```wgsl
let color = MIN_COLOR * (1.0 - alpha) + MAX_COLOR * alpha
```

== The result 

We've done a lot of work. Let's just see if we're getting results. Here's what I got at roughly this point:

#figure(
  image("screens/world_map1.png", height: 70%, alt: "a heightmap of Earth, showing Africa and Eurasia.")
)

== Slightly more complex color blending

But the earth has water on it, right?

We could add a flat plane at height 0 for the water, but let's make a simple challenge based on what we just learned.

If we wanted to make the fragment color _blue_ when it is below the water, what would we do?

[class]

== Slightly more complex color blending (2)

We can perform the same calculation as before, but with a different color and with different heights.

Start with:
```wgsl
var color: vec3;
if (height < 0) {
  let alpha = (height - MIN_HEIGHT) / -MIN_HEIGHT;
  color = mix(MIN_COLOR_WATER, MAX_COLOR_WATER, alpha);
}
else {
  // land calculation goes here but 0 instead of MIN_HEIGHT
}
```

== Slightly more complex color blending result:

#figure(
  image("screens/world_map2.png", height: 80%, alt: "the same view of the heightmap as the last screenshot, but now the underwater terrain is varying shades of blue.")
)

We will do nicer color blending soon, but it's a start.

#focus-slide("Questions?")

== Heightmap limitations

== Voxels

#focus-slide("Questions?")

== What about random terrain

A real heightmap is cool and all, but what about procedurally generated terrain? It features hugely in many popular game franchises, Minecraft being the most notable.

In this lecture, I'll teach you the algorithm Minecraft uses. It's extremely versatile, so we'll be using it to generate smoothly varying terrain instead of blocky voxel terrain.

You can use this same technique to generate voxel terrain. You can even use it to generate overhangs or caves (3D Perlin noise) which is what Minecraft does.

== Procedural generation

We're going to learn an algorithm for procedural generation.

This is often taken to be a synonym for "random generation", and sometimes it is, but that's not strictly what the term means for us.

Procedural generation means "generating using a procedure". As opposed to loading something already rendered from a file.

So instead of loading a heightmap that was already created, we can use a procedure to generate one...

== Procedural Generation (2)

#text(20pt)[
Procedural generation _can_ be random. For example, you could have a procedure that uses an arbitrary input (a seed) to generate a random world. Minecraft does this.

But it doesn't have to be. Games like Daggerfall and Elite have the same world every time, but the world is the outcome of a random procedure.
]

#figure(
  [
    #image("screens/daggerfall_unity.jpg", height: 50%, alt: "a game screenshot")
    #place(top+right, dx: -1%, dy: 1%, game-name("Daggerfall (unity version)"))
  ]
)

== Procedural generation (3)

There are several benefits to this:
+ A procedure is expected to take up way less space than a large image file full of terrain heights.
+ Procedures do not have to be finite. They can generate infinite terrain.
+ Procedures can be tuned to generate a lot of land with very little human effort. They can save labor for when quantity is more important than quality (nothing beats hand-crafted terrain, but sometimes quantity has its own quality)

== Fractal vs. Value vs. Gradient noise

Techniques for generating random terrain fall under many different categories. Here are a few:
- Value noise: the generator looks at heights in a region around a point to determine what height it should be.
- Gradient noise: the generator uses the slope (i.e., gradient vector) of the land around to determine what height it should be.
- Fractal noise: the generator uses a fractal process (i.e., repeated subdivision) to generate terrain.

== Previous iterations

In the past, I used fractal terrain techniques. In particular, I used the Diamond-squares algorithm.

These often look really nice.

However, they have limitations when being used for infinite streaming terrain. In particular: they are less parallelizable. You have to store adjacent terrain chunks to generate new ones that aren't misaligned.

Therefore, I've switched over to using *Perlin noise* for these lectures.

The old technique is still up in the course slides on Canvas, and it still works well, however.

== Ken Perlin


