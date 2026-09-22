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
