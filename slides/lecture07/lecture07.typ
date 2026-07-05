#set document(title: "Notes on Computer Graphics: Lecture 7")

#import "@preview/touying:0.7.4": *
#import themes.simple: *
#import "@preview/shadowed:0.3.0": shadow
#import "../util.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/cetz:0.5.2" as cetz: canvas, draw

#show link: set text(blue)
#show: slide-theme


#title-slide[
  = Computer Graphics: Lecture 7
  == Textures and Bind Groups

  \
  \
  \
  \
  Slide Deck © Grant Williams, 2026, License: #link("https://creativecommons.org/licenses/by-sa/4.0/deed.en")[CC-BY-SA 4.0] 
]

== Welcome Back!

Last time we learned all about color blending and vertex attributes.

We learned that every vertex can have multiple attributes attached to it, and that this data is passed to the vertex shader, one per `@location`.

We learned that we can interleave attributes by putting each attribute in some order, one per vertex.

We learned that the stride of a vertex buffer is how much to add to get from one vertex to another. This is the size of a vertex if attributes are interleaved. If we split attributes into different buffers, this will be the length of one "row".

== This time

We're finally going to learn about textures.

This is an important topic. Textures are the cornerstone of 3D graphics. Not only do they give objects their detail, they can be used as lookup tables for all kinds of effects (shadows, normal maps, reflections, the sky, many more things)

Furthermore, when we render a frame, we're actually drawing into a texture (which is why I've been handwaving `context.getCurrentTexture()`).

== What is a texture?

#stack(
  dir: ltr,
  spacing: 5%,
  box(width:50%)[
Textures are images that we project on 3D shapes

But this is a bit oversimplified.

In fact, they have a complex internal storage, with multiple levels of images of different sizes.

We will learn the details in the advanced texturing later in the course.
  ],
  box(width: 50%)[
    #figure(
      numbering: none,
      image("screens/y2k_stone.png", scaling: "pixelated", width: 70%, alt: "A stone surface texture."),
      caption: [A texture. (by #link("ggbot.net", "GGBot")--scaled up beyond its intended dimensions)],
    )
  ]
)

== Why textures?

Textures actually serve a lot of purposes.

Our first use of them will be to give detail to 3D objects.

Since we haven't learned about perspective yet (it's coming, I promise!), textures will be a way to draw pixels on the screen instead of just colored gradients.

They can also be lookup tables, temporary storage, palettes, depth buffers, and even define shadows. They are extremely versatile.

== What textures?

Textures can be 1-dimensional, 2-dimensional, or 3-dimensional. We will discuss 2-dimensional textures mainly in this course as those are the most commonly used.#footnote[1D textures are useful for gradients and borders, 3D textures are useful for volumetric fog and medical imaging.]

In the same way that a normal image is composed of _pixels_, textures are composed of *texels*.

A *texel* is a _TEXture ELement_.

Why a different term? Because like I mentioned before, textures actually have multiple levels. A texel is a pixel in one of the levels. 

== How textures?

In 3D textures are not just images we draw "at an angle".

Instead, we draw a triangle, but we  *sample* the texture as we do so.

*Sampling* a texture is like looking up a pixel in an image, but it is smooth. We can smoothly look up a point in between several texels.

We do this for every fragment on the triangle.

The key is knowing specifically which texels to look up at which point on the triangle.

== Let's get concrete

Textures are a little weird, but once you understand how they work, they gradually become intuitive.

To make them intuitive, we're going to focus on one simple problem: drawing a textured quad.

That is, we're going to draw a rectangle, but we'll modify our fragment shader to look up the texels instead of blending a color.

== UV coordinates

Textures are sampled using a special coordinate system. Understanding this coordinate system is critical to getting good at textures.

The coordinate system is called *uv* coordinates.

*u* and *v* are dimensions, like xy or rgb.

They are a way to describe the position of a sample on a texture, regardless of how big the texture is.

Let's see how they work...

== Example UVs 

#stack(dir: ltr, spacing: 5%,
figure(
  alt: "a diagram showing a texture with 4 points super imposed on it. The top left point is the origin (0, 0). The top right point has coordinates (1, 0). The bottom left point has coordinates (0, 1). The bottom right point has coordinates (1, 1).",
canvas(length: 9cm, {
  import draw: *;

  set-viewport((0, 0), (1, 1), bounds: (1, -1))

  content((0,0), (1,1), anchor: "north-west", auto-scale: true, image("screens/y2k_stone.png", width: 100%, height: 100%, fit: "stretch", alt: "a square texture image"))
  circle((0, 0), radius: 0.03, fill: red, alt: "top left corner")
  content((-.15, 0), [(0, 0)\ origin])
  line((-.15, .15), (-.15, .9), mark: (end: ">"), alt: "v axis line pointing down")
  content((-.1, .5), angle: 270deg, [*v* axis (down)])
  circle((0, 1), radius: 0.03, fill: white, alt: "bottom left corner")
  content((-.15, 1), [(0, 1)])
  line((0, -.1), (.9, -.1), mark: (end: ">"))
  content((0.5, -.15), [*u* axis (right)])
  content((1,-.1), [(1, 0)])
  circle((1, 0), radius: 0.03, fill:white, alt: "top right corner")
  content((.75, 1.1), [bottom right, (1, 1)])
  circle((1, 1), radius: 0.03, fill: white, alt: "bottom right corner")
})
),
box(width: 50%)[
  The u, v coordinate system treats the _origin_ as the top left.

  "u" and "v" refer to far to go down and right.

  Our goal is to choose a point to "sample", meaning, to retrieve the color at.

  If we choose (0.5, 0.5), we are sampling the very center of the image.
]
)

== Here is a 4-by-4 texture with UV coordinates

#figure(
  numbering: none,
  canvas(length: 7cm, {
    import draw: *;

    set-viewport((0, 0), (1, 1), bounds: (1, -1))
    let rows = 4
    let cols = 4


    for row in range(rows) {
        for col in range(cols) {
            let x = col / cols + 1 / cols / 2;
            let y = row / rows + 1 / rows / 2;

            circle((x, y), radius: 0.02, fill: red)
        }
    }
    grid((0, 0), (1, 1), step: .25)

    circle((0, 0), radius: 0.02, fill: yellow)
    content((-.03, 0), anchor: "east",  text(14pt)[(0, 0)])

    content((0.125, 0.155), anchor: "north", text(11pt)[(.125, .125)])
    content((.125, .395), anchor: "north", text(11pt)[(.125, .375)])

    circle((0.5, 0.5), radius: 0.02, fill: yellow)
    content((0.55, 0.55), text(14pt)[(0.5, 0.5)], anchor: "west")
    mark((0.51, 0.51), (0.5, 0.5), ">")


  }),
  alt: "A 4-by-4 grid, demonstrating a simple 4-by-4 texture's u/v coordinate addressing. The top left corner of the image is point (0, 0). The center of the top left texel is actually (0.125, 0.125), because (0, 0) refers to its extreme corner, not its center. Its southern neighbor, row 1 column 0, has center coordinate (0.125, 0.375).",
  caption: "Each cell is .25 wide and tall. The center (0.5, 0.5) is between 4 texels. If we sample that point, the GPU could give us one of those 4 colors, or it could average them together depending on our sampling mode."
)

== With me so far?

Textures are like images, with _texels_ instead of _pixels_.

The main things we do to textures is _sample_ them, which means to look up a color from a position on the texture.

We don't provide the raw coordinates of the texel, instead we use the u/v coordinate system.

We do this so that we could replace the texture with a higher-resolution one (more pixels) and have the addressing still return roughly the same colors.

== With me so far? (2)

U/V coordinates have (0, 0) at the top left. The U coordinate points right, the V coordinate points down.

(0.5, 0.5) is the _center_ of the texture. For a power of 2 sized texture it refers to the center of a square of 4 texels.

(0, 0) refers to the top left corner of the top left texel. 

To get the actual center of the texel, you have to add an offset, which is half the width of a texel in u/v coordinates.

1/width is the width of a texel in u coordinates. Half of that is the distance from the left border of a texel to its center. Likewise for V.

#focus-slide("Questions?")

== Texture mapping a triangle

The act of applying a texture to something is called _texture mapping_.

Many texturing techniques have "mapping" in their name: normal mapping, shadow mapping, parallax mapping, etc.

What we want to do is color mapping. Have the _color_ of a fragment come from a texture, instead of being blended from vertex output colors like we did last time.


== Texture mapping a triangle (2)

Previously, we took advantage of the fact that colors were _interpolated_ before the hit the fragment shader.

That is, if one vertex of a triangle was red, one was green, and one was blue, the fragment shader would receive the correct blend of red, green, and blue depending on how close it was to each vertex.

We want to do _the same thing_ but with u/v coordinates instead of colors.

If we do that, we'll end up "blending" the u/v coordinates, so that nearby fragments sample nearby texels.

== Texture mapping example

To understand this, let's imagine a single triangle.

This triangle will have a u/v attribute, which stores the u/v coordinates at each of its three vertices.

Each fragment on the surface of the triangle will interpolate between these three u/v values.

Inside the fragment shader, when the fragment samples the texture, it will pull a color that corresponds to the unique u/v coordinates of that fragment.

== Texture mapping example (2)

#figure(
  alt: "An image of a right triangle whose corner is in the bottom right. This triangle is mapped such that its corner point has u/v (1, 1), its top point has u/v (1, 0), and its left point has uv (0, 1). Therefore, the point between the left and the corner has uv (0.5, 1). There is a grid of points showing the coordinates for each one.",
  caption: "Each fragment (pixel within triangle) will receive an interpolated u/v coordinate. Therefore, the color looked up from the texture will be different for each one.",
  canvas(length: 8cm,{
    import draw: *;

    set-viewport((0, 0), (1, 1), bounds: (1, -1));

    let rows = 5;
    let cols = 5;
    let grid_w = 1 / rows;
    let grid_h = 1 / cols;
    let off_u = grid_w / 2;
    let off_v = grid_h / 2;
    let text_eps = 0.02;

    for row in range(rows) {
      for col in range(cols - row, cols) {
        let u = grid_w * col + off_u;
        let v = grid_h * row + off_v;
        let ut = calc.round(u, digits: 2);
        let vt = calc.round(v, digits: 2);
        circle((u, v), radius: 0.02, fill: yellow)
        content((u, v - text_eps), anchor: "south", text(12pt)[(#ut, #vt)])
      }
    }


    line((1, 1), (0, 1), (1, 0), close: true)

    circle((1, 1), radius: 0.02, fill: red)
    content((1.05, 1), anchor: "west", [(1, 1)])
    circle((1, 0), radius: 0.02, fill: red)
    content((1.05, 0), anchor: "west", [(1, 0)])
    circle((0, 1), radius: 0.02, fill: red)
    content((-.05, 1), anchor: "east", [(0, 1)])

    
    //circle((0.5, 1), radius: 0.02, fill: yellow)
    //content((0.5, 1.05), anchor: "north", text(14pt)[(.5, 1)])
    //circle((0.6, 1), radius: 0.02, fill: yellow)
    //content((0.6, .95), anchor: "south", text(14pt)[(.6, 1)])
    //circle((0.7, 1), radius: 0.02, fill: yellow)
    //content((0.7, 1.05), anchor: "north", text(14pt)[(.7, 1)])
   /* 
    circle((.7, .55), radius: 0.02, fill: yellow)
    content((.7, .6), radius: 0.02, text(14pt)[(.7, .55)])*/
  })
)

== Texture mapping example (3)

#figure(
  numbering: none,
  alt: "The right triangle superimposed on the texture, showing which points on the triangle come from which points on the texture.",
  caption: "Each fragment gets a uv coordinate that is somewhere between the uv coordinates of the corners. This uv coordinate is used to look up the closest texel color. So we end up with a triangle cut-out of the texture. (There is one unique point for each pixel, I'm not showing all of them)",
  canvas(length: 8cm, {
    import draw: *;

    set-viewport((0, 0), (1, 1), bounds: (1, -1))

    

    rect((0, 0), (1, 1))
    content((0, 0), (1, 1), auto-scale: true, image("screens/halftex_triangle.png", fit: "stretch", width: 100%, height: 100%))

    let rows = 5;
    let cols = 5;
    let grid_w = 1 / rows;
    let grid_h = 1 / cols;
    let off_u = grid_w / 2;
    let off_v = grid_h / 2;
    let text_eps = 0.02;

    for row in range(rows) {
      for col in range(cols - row, cols) {
        let u = grid_w * col + off_u;
        let v = grid_h * row + off_v;
        let ut = calc.round(u, digits: 2);
        let vt = calc.round(v, digits: 2);
        circle((u, v), radius: 0.02, fill: yellow)
        content((u, v - text_eps), anchor: "south", text(12pt, white)[(#ut, #vt)])
      }
    }
  })
)