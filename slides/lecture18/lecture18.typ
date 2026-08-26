#set document(title: "Notes on Computer Graphics: Lecture 18")

#import "@preview/touying:0.7.4": *
#import themes.simple: *
#import "@preview/shadowed:0.3.0": shadow
#import "../util.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/cetz:0.5.2" as cetz: canvas, draw

#show link: set text(blue)
#show: slide-theme


#title-slide[
  = Computer Graphics: Lecture 18
  == Advanced Texturing

  \
  \
  \
  \
  Slide Deck © Grant Williams, 2026, License: #link("https://creativecommons.org/licenses/by-sa/4.0/deed.en")[CC-BY-SA 4.0] 
]


== Welcome back!

Last time we learned all about cube topologies.

They were surprisingly involved, and we learned two in particular:
- UV-spheres
- Cube-spheres

[How do they differ, and does anyone recall the secret 3rd option?]

We also learned how to texture map them. UV-spheres straightforwardly wrap a texture around them cylindrically.

Cube-spheres _could_ use the same trick, but there's a better way...

== Welcome back! (2)

We saw that there exists a special kind of texture that is designed to be sampled with a vector, as if the texture is on the surface of a cube, and the sample is a vector pointing outward from the center of the cube.

It's called a *cube-map*, and we learned how to load and to use them.

Cube-maps basically remove the need to duplicate vertices of cubes so the top can have different UV coordinates from the sides.

But they can also unlock two very cool techniques:
+ Sky boxes. Very important to 3D games in particular.
+ Environment maps: cool reflections which are cheap to compute.

== This time

So what's up with the title of this lecture, _Advanced Texturing_? Those cube maps seemed pretty advanced to me!

Well, there have been a lot of important aspects of tetures we've been ignoring so far namely:
- How they even work. Like, how does the GPU does sampling?
- And how does that sampling work with perspective?
- And what happens if the texture is too far or too close?
- And what happens if the texture is at an angle?

It might not have occurred to you that these would be problems, but...

== How do textures even work?

Let's start by reminding ourselves how textures work.

For now, we're going to restrict our discussion to 2D flat textures.

2D (non-cube) textures are sampled with 2-D coordinates in UV space.

That means, `0, 0` is the top left corner of the texture, and `1, 1` is the bottom right corner.

Let's make a really simple texture so we can plot the UVs...

== A very simple tile texture


#let tiles = canvas(length: 9cm, {
  import draw: *;

  set-viewport((0, 0), (1, -1))

  let rows = 4;
  let cols = 4;
  let tile_w = 1 / rows;
  let tile_h = 1 / cols;

  for row in range(rows) {
    for col in range(cols) {
      let u = col * tile_w;
      let v = row * tile_h;
      let quad1 = u < 0.5 and v < 0.5;
      let quad4 = u >= 0.5 and v >= 0.5;
      let color = if quad1 or quad4 { white } else { black }

      rect((u, v), (u + tile_w, v + tile_h), fill: color)
      circle((u + tile_w / 2, v + tile_h / 2), fill: red, radius: 0.01)
    }
  }

  grid((0, 0), (1, 1), stroke: blue, step: (tile_w, tile_h))
  content((-.01, 0), anchor: "east", [(0, 0)])
  content((1.01, 0), anchor: "west", [(1, 0)])
  content((-.01, 1), anchor: "east", [(0, 1)])
  content((1.01, 1), anchor: "west", [(1, 1)])
  circle((0.5, 0.5), radius: 0.02, fill: blue)
  content((.51, .55), anchor: "west", text(fill: blue)[(0.5, 0.5)])
  content((0.15, 0.14), anchor: "west", text(fill: red, size: 13pt)[(.125, \ .125)])
  content((0.4, 0.14), anchor: "west", text(fill: red, size: 13pt)[(.375, \ .125)])
  circle((0.25, 0.25), radius: 0.01, fill: blue)
  content((.26, .28), anchor: "west", text(fill: blue, size: 13pt)[.25, .25])
  
})

#figure(
  tiles,
  alt: "a 4-by-4 grid showing a tile texture. the top left and bottom 4 right tiles are black. The others are white. The center of each tile is represented by a dot. The first tile's center is labeled as (.125,.125), and each tile right or down adds .25 to the appropriate dimension.",
  numbering: none,
  caption: [A 4-by-4 texel texture. Notice that the centers of the texels are offset by half a texel in UV space.]
)

== Mapping that texture

We've already seen how to map textures that aren't distorted. E.g.,:

#let drawTilesMapped = {
  import draw: *;

  let rows = 3;
  let cols = 3;
  let tile_w = 1 / rows;
  let tile_h = 1 / cols;

  for row in range(rows) {
    for col in range(cols) {
      let u = col * tile_w;
      let v = row * tile_h;
      let quad1 = u < 0.5 and v < 0.5;
      let quad4 = u >= 0.5 and v >= 0.5;
      let color = if quad1 or quad4 { white } else { black }

      rect((u, v), (u + tile_w, v + tile_h), fill: color)
    }
  }

  grid((0, 0, 0), (1, 1, 0), stroke: blue, step: (tile_w, tile_h))
  content((-.01, 0), anchor: "east", [(0, 0)])
  content((1.01, 0), anchor: "west", [(0.75, 0)])
  content((-.01, 1), anchor: "east", [(0, .75)])
  content((1.01, 1), anchor: "west", [(.75, .75)])

}

#let tilesMapped = canvas(length: 7cm, {
  import draw: *;

  set-viewport((0, 0), (1, -1))
  drawTilesMapped
})

#figure(
  tilesMapped,
  alt: "The first 3 rows and columns of the previous 4-by-4 grid. From top-left clockwise, the UV coordinaes are (0, 0), (.75, 0), (0, .75), and (.75, .75).",
  numbering: none,
  caption: [This is what we get if we use different UV coordinates.]
)

== Rotating the texture 

But what if we want to rotate the polygon it's mapped onto?

#let tilesRotated = canvas(length: 7cm, {
  import draw: *; 
  set-viewport((0, 0, 0), (1, -1, 0))
  perspective(drawTilesMapped, distance: 1)
})

#figure(
  tilesRotated,
  alt: "The previous texture rotated by about 45 degrees in the y axis and 30 degrees in the x axis."
)


== Rotating the texture (2)

Remember that every pixel in that quad is going to have its fragment shader be executed.

The fragment shader will call `textureSample(tex, samp, uv)`.

`tex` and `samp` are constants. But `uv` is an attribute, which means that it is interpolated.

There are actually 3 different ways that it can be interpolated:
- `flat`: the values of the attribute for the first vertex are copied for all the fragments of that triangle.
- `linear`: linear interpolation
- `perspective` (default): perspective-correct interpolation

== Linear interpolation:

Flat interpolation is fairly boring, but linear interpolation isn't. It's *almost* what we want, but there's a reason it's not the default.

Suppose we want to draw this X-texture to a quad:


#let tl1 = (-1, 1, 0);
#let tr1 = (1, 1, 0);
#let br = (1, -1, 0);
#let bl = (-1, -1, 0);
#let c1 = (0, 0, 0);

#let xTexture(tl, tr, br, bl, c) = {
  import draw: *;

  set-viewport((0, 0), (1, 1))
  
  line(tl, tr, br, bl, close: true)
  line(bl, tr, stroke: (thickness: 0.04))
  line(tl, br, stroke: (thickness: 0.04))
  line(bl, tr, stroke: (paint: red, thickness: 0.02))
}


#figure(
  canvas(length: 3cm, {
    xTexture(tl1, tr1, br, bl, c1)
  }),
  alt: "a texture of a cross",
  caption: [The red line is the edge between 2 triangles.],
  numbering: none,
)

== Linear interpolation (2):

Now, suppose we want to rotate it a bit:

#let d = 2
#let tl2 = (tl1.at(0) / d, tl1.at(1) / d, 0)
#let tr2 = (tr1.at(0) / d, tr1.at(1) / d, 0)
#let c2 = (
  ((bl.at(0) + br.at(0)) / 2) - .15,
  -.2
)

#let xTextureLinear(tl, tr, br, bl, c) = {
  import draw: *;

  set-viewport((0, 0), (1, 1))
  
  line(tl, tr, br, bl, close: true)
  line(bl, tr, stroke: (thickness: 0.04))
  line(br, c, stroke: (thickness: 0.04))
  line(tl, c, stroke: (thickness: 0.04))

  line(bl, tr, stroke: (paint: red, thickness: 0.02))
}

#figure(
  canvas(length: 3cm, {
    xTextureLinear(tl2, tr2, br, bl, c2)
  }),
  alt: "the texture layed down flat. The 'bars' of the X are no longer straight. One is V-shaped.",
  caption: [Notice that the X is now warped.],
  numbering: none,
)

For each pixel, we sample a UV coordinate by linearly interpolating between the XYZ coordiantes of each vertex.

Imagine the top edge of the quad is 2 distance units away...

== Linear interpolation (3):

For each pixel, we perform the barycentric calculation we talked about waaay earlier in the semester.

We determine how close we are to the three points of its triangle, and we average the UV coordinates for that fragment.

Notice that this _does not give a correct result_ with textures.

[Why?]

== Linear interpolation (4)

Fundamentally the issue is that correcting for distance puts us in a reciprocal coordinate space.

Remember the w-divide: we put the distance from the camera of each point in the w coordinate.

This makes it so that _the center of the line between two points is not actually where the midpoint would be_.

That's why the perpendicular line stops being perpendicular. The further away we get from the edges of the triangle, the more difference there is between the perspective-correct point and the linearly interpolated texture sample.

== Linear interpolation (5)

Of course, an X shape is a worst-case scenario for linear interpolation, and it's actually cheaper than the perspective correct option.

In fact, this was the way some early realtime 3D hardware handled textures. It was famously how the Playstation interpolated textures.

Linear interpolation is also called "affine texture mapping".

It led to the famous "PS1 texture warping" ...

== Linear interpolation example

#figure(
  image("screens/affine_textures.jpg", alt:"an image of the game Metal Gear Solid on the Playstation in which this kind of affine texture warping is visible.", width: 70%),
  caption: [Title image from #link("https://danielilett.com/2021-11-06-tut5-21-ps1-affine-textures/", "a blog article") about recreating the PS1 warping effect using OpenGL],
  numbering: none,
)

== Linear interpolation fixes

It's possible to mitigate the issue with linear interpolation. Notice that only the line that was _not on_ the triangle edge was wrong. If you split quads into smaller quads, more of the texture coordinates are close to an edge, making the problem less noticeable.

In fact, this is exactly what Sony recommended developers do, according to #link("https://pikuma.com/blog/how-to-make-ps1-graphics", "this excellent article on making PS1-style graphics").

However, a better solution is to properly account for perspective when _sampling_ the texture.

== Fun fact

The Nintendo 64 did perspective-correct rendering, allowing level designers to use giant polygons without subdividing them if they wanted.

This would typically result in blurry textures, but they would be perspective-correct blurry textures.

This is one reason why textures often look completely broken with N64 games are ported to the PS1 without adjusting the meshes.

#focus-slide("Questions?")

== Fixing It

Okay, I have a question.