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

Cube-maps allow textures to be sampled with a _direction_ instead of a point. 

They can also unlock two very cool techniques:
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

== Bilinear filtering

We've seen that we sample textures using fractions. What happens when one of them doesn't correspond to the center of the pixel?

For example, what if we sample (0.5, 0.5) in the previous image?

We can see that it's in the center, which means it's actually between 4 texels. But two of those texels are black, and two are white. What is the color that we get back?

Answer: it depends on our sampling mode.

== Bilinear filtering (2)

In `'nearest'` mode, we perform nearest neighbor sampling. If we were closer to a black texel we would get black, and if we were closer to a white texel we would get white.

In this case, we are equally close to either color, so it's up to the implementation which one we get.

But in `'linear'` mode, we perform linear filtering in two dimensions. This is called *bilinear filtering*...

== Bilinear filtering (3)

#figure(
  stack(dir: ltr, spacing: 4%,
    box(width: 48%, image("screens/tiny_checker.png", scaling: "pixelated", height: 70%, alt: "a 2-by-2 tile board with perfect fidelity")),
    box(width: 48%, image("screens/tiny_checker.png", height: 70%, alt: "the same image, but blurry due to being bilinear filtered to an extreme degree")),
  ) ,
  numbering: none,
  caption: [Left: a 2-by-2 image with perfect fidelity, blown up. \ Right: a 2-by-2 image smoothly filtered bilinearly]
)

== But that looks horrible!

In this case, the texture happens to be perfect for nearest filtering, which is why it's an option.

However, keep in mind that most textures are meant to be in the background, and having sharply defined pixels makes them stand out...

== It looks better in practice

Sometimes we like the light blurring, especially for background elements and natural textures. Example: #link("https://learnopengl.com/Getting-started/Textures", "this image") from #link("https://learnopengl.com", "learnopengl.com").

Also keep in mind that stretching a 2-by-2 pixel texture over half the screen is a pretty extreme case. It's usually not as noticeable.

So how does the math behind this work?

== Bilinear filtering (4)

When we sample a texture, we also look up the values of the 4 closest texels that surround the point we sampled.

We compute two mean U values: one between the top two points and one between the bottom two points.

Those means are weighted by how close we are to each point. If we are 30% from the right side, we compute `(30% * left_side + 70% * right_side)`. We do this _twice_, once for the two texels above our sample, and once for the two texels below our sample.

== Bilinear filtering (5)

Then, we average those two averages based on how close the V coordinate is from them.

So if we're 10% away from the top two texels in the V dimension, we would compute `(100% - 10%) * top + 10% * bottom`.

This final average would be our result.

Here's an illustration...

== Bilinear filtering in grayscale

#figure(
  image("screens/Bilin3.png", height: 70%, alt: "illustration of bilinear filtering. The 4 nearest texels are, clockwise from top-left, 91, 210, 95, and 162."),
  numbering: none,
  caption: text(18pt)[
    Suppose we sample `(14.5, 20.2)`. First, this is halfway between `91` and `210` on top, so the top average is `150.5`. Likewise, the bottom average is exactly between `162` and `95`, resulting in `128.5`. We are 20% away from the top sample, so we get `150.5 * 80% + 128.5 * 20% = 146.1`
    \
    #link("https://en.wikipedia.org/wiki/File:Bilin3.png", "Image") by Jayson Kostelyk, Vizerai; Public Domain
  ]
)

== Bilinear filtering in color

To do this in RGB space, we just apply the same technique to the R, G, and B channels separately.

Either way, we get the ability to smoothly sample the texture.

In the early days, the Nintendo 64 supported this kind of texture filtering, while the Playstation didn't. It led to the distinct difference between the two consoles' visual appearance...

== PS1 vs. N64 comparison

#figure(
  [
  #image("screens/n64_v_ps1.jpg", height: 75%, alt: "side by side comparison showing the effects of the two approaches to texture mapping")
  #place(bottom + left, game-name("Mega Man Legends"))
  #place(bottom + right, game-name("Mega Man 64"))
  ],
  numbering: none,
  caption: text(18pt)[Title card for #link("https://www.youtube.com/watch?v=39jnFUNiCME", "this comparison video") by #link("https://www.youtube.com/@vcdecide", "VCDECIDE") between a Playstation and Nintendo 64 version of a game, showing how texture filtering choice can significantly affect the overall image.]
)

== PS1 vs. N64 comparison

Okay, that one was pretty bad for the N64. Here's a more favorable one:

#figure(
  [
  #image("screens/n64_v_ps1_2.png", height: 70%, alt: "another side by side comparison showing the effects of the two approaches to texture mapping")
  #place(bottom + left, game-name("Quake II (N64)"))
  #place(bottom + right, game-name("Quake II (PS1)"))
  ],
  numbering: none,
  caption: text(18pt)[Screenshot from #link("https://www.youtube.com/watch?v=UtVC0xJm_3o", "this comparison video") by #link("https://www.youtube.com/@GroupMPro", "Group M Pro"), which also shows how colored lighting has a major effect on graphics.]
)


#focus-slide("Questions?")

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
  ((bl.at(0) + br.at(0)) / 2) - .2,
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

Suppose we determine how close we are to the three points of its triangle, and we compute the weighted mean of the UV coordinates for that fragment.

This _does not give a correct result_ with textures (or colors, or anything on the surface of the triangle and not at the points).

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

Okay, I have a question: how do we fix this? If we can't linearly interpolate over the triangle, then what does the GPU actually do, and why have we never seen that PS1 texture warping (unless some of you deliberately enabled `'linear'` mode to experiment)?

The GPU does *perspective-correct* interpolation, but how?

Well, it has to do with that tricky w-divide again...

== Perspective-correct interpolation

The fundamental problem with linear interpolation is that the "depth" dimension does not scale linearly with respect to the X and Y dimensions.

Remember the relationship: `x' = x / d`, `y' = y / d`.

That's a reciprocal function, not a linear one.

When the pixel in question is on a vertex, it ends up getting the correct value (because there is no interpolation), but otherwise, it's wrong.

Therefore, we need a different coordinate space in order to interpolate.

== Perspective-correct interpolation (2)

Let's say our goal is to compute the correct UV values for each pixel.

Instead of just interpolating U and V directly, we first interpolate `u / w` and `v / w`...

So suppose we have two vertices in which the close one is `w = 1`, and the far one is `w = 10`. And suppose the `u` coordinate of the close one is `u = 0.5`, and the `u` coordinate of the far one is `u = 0.75`. 

Instead of linearly interpolating between `0.5` and `0.75` as we go along the triangle, we linearly interpolate between `0.5 / 1` and `0.75 / 10`...

== Perspective-correct interpolation (3)

Of course, `0.75 / 10 == 0.075`, which is not the correct U coordinate, so we also have to undo this transformation.

We do that by dividing by `w` each time we need to sample the interpolated attribute (i.e., at each fragment).

So let's say we're halfway between the first vertex and the second one:
- Linearly interpolate between `0.5` and `0.075`: `50% * 0.5 + 50% * 0.075 = 0.2875`
- Linearly interpolate between `1 / 1` and `1 / 10` (i.e., the reciprocal of w): `50% * 1 + 50% * 1/10 == .55`
- [Then what?]

== Perspective-correct interpolation (4)

Once we have both the interpolated `u/w` and `1/w` values, we divide `u/w` by the interpolated `1/w`.

In our case: `0.2875 / .55 =~ .523`

Note: that _is_ between `0.5` and `0.75`, but it's much closer to `0.5`. 

Let's gain more confidence that it will interpolate by picking a value closer to the distant vertex: `w = 9.9`:
- `1% * 0.5 + 99% * 0.075 == 0.07925 `
- `1% * 1 + 99% * 1/10 == 0.109`
- `0.07925 / 0.109 =~ 0.727`  . Very close!

== What it does

Fundamentally, when we do this kind of interpolation, we place the "center" of the texture appropriately farther away than just the "center" of the x.

#figure(
  canvas(length: 7cm, {
    xTexture((-0.4, 0.4), (0.4, 0.4), (1, 0), (-1, 0), (0.5, 0.5))
  }),
  alt: "the x texture from earlier, but perspective-correct. the middle of the x is closer to the distant edge of the quad.",
  caption: [Notice how the "center" of the X is proportionately closer to the top edge. That means we interpolate the closer part of the texture much more slowly (causing it to cover more area). This is what we observed with the `w = 5` being much closer to the close value.],
  numbering: none
)

== Summary of perspective correct sampling:

So, when you use the default `perspective` mode for attribute interpolation in the fragment shader, here is what you're actually doing:
- After the vertex shader produces the `position` value, we use the `w` coordinate to divide _all_ the attributes we selected `perspective` for (potentially including UV, normal, and color)
- For each attribute `a`, interpolate `a / w` instead of `a` by itself.
- In addition, interpolate `1 / w`, which has the same nonlinear relationship with the screen-space fragments.
- Finally, divide `a / w` by `1 / w` to get the final attribute.
- If this is a UV coordinate, we can use this new interpolated value to lookup the correct sample of the texture.

#focus-slide("Questions?")

== What even _is_ a texture?

#stack(dir: ltr, spacing: 10%, 
box(width: 50%)[If the transformation stuff wasn't weird enough, this is really going to be uncomfortable.

Make sure you're sitting down, this is a lot to take in...

What if I told you... a 2D texture is not actually just a 2D image...
],
box(width: 40%)[
  #image("screens/morpheus.webp", alt: "morpheus from the matrix")
]
)

== What even _is_ a texture? (2)

It's usually a _pyramid_ of 2D images, each one a quarter the size (i.e., half the side lengths) of the one before:

#figure(
  canvas(length: 6cm, {
    import draw: *;
    set-viewport((0, 0), (1, 1))
    perspective(distance: 0.5,
    {
      rect((0, 0, 0), (1, 1, 0))
      content((0.3, 0.4, -0.3), [layer 0])
      rect((0.25, 0.25, 0.5), (0.75, 0.75, 0.5))
      content((0.35, 0.4, 0.5), [1])
      rect((0.375, 0.375, 1), (0.625, 0.625, 1))
      content((0.5, 0.5, 1), [2])
    })
  }),
  alt: "a texture pyramid with 3 layers. Each layer has half the side length of the layer before.",
  numbering: none,
  caption: [This pattern usually continues until the last layer has a single pixel.]
)

== What even _is_ a texture? (3)

The base layer of the texture, layer 0, is the original image. Typically an uncompressed version of whatever was stored in the texture file. Pretend it's a 1024-by-1024 texture.

Layer 1 is a 512-by-512 version of the same texture. It's just lower resolution. Each pixel is the average between 4 pixels in the larger layer.

Layer 2 is 256-by-256.

And so on...

[For an `n-by-n` texture, how do we calculate how many layers we need to get to 1 pixel?]

== But _why_?

Why on earth would we do that?

Well, we didn't always. Before the Nintendo 64, a lot of consumer 3D hardware did not work this way.

Let's look at why that was a problem...

== A simple scene

Let's look at `sample15` together. Ignore the sphere for now.

Instead, focus on the horrible shimmering.

This is called *texture aliasing*.

