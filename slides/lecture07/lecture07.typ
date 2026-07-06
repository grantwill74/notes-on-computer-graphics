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
  caption: [Each fragment gets a uv coordinate that is interpolated between the uv coordinates of the corners. This happens for _every fragment_, but I'm only showing a few. (Imagine that there is a dot for every pixel on the screen)],
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

== Comprehension check

What would happen visually if we continued to sample (1, 1) for the bottom left point, but we sampled (1, .75) for the top right point, and (.75, 1) for the bottom left point, but the triangle is the same size.

What would it look like?

[Take a second and think about it]...

== It would zoom in on the corner

#stack(dir: ltr, spacing: 5%,
box(width: 50%)[
  #set text(20pt)
We sample a smaller portion of the texture (the lower right sixteenth of it), but we are blowing it up over the same size of rectangle.

The number of pixels we're drawing stays the same, but the number of _texels_ we're sampling is 1/16th as many.

Therefore, the texture is zoomed in, and looks grainy. #footnote[this is why games from the 5th generation of game consoles (i.e., the PS1, N64 generation) look so grainy/blurry. The textures had to be small due to hardware limitations.]
],[
  #image("screens/grainy_triangle.png", height: 85%, alt: "a screenshot of a grainy-looking triangle. A small number of texels has been expanded into a large triangle.")
]
)

#focus-slide("Questions?")

== Let's get artistic

#stack(dir: ltr,
box(width: 50%)[
Now that we understand a bit more about UV coordinates, let's try to think artistically about them.

That is, instead of imaging _what_ it will look like, let's trying imagining how to achieve an effect that we want. This is a question we will often find ourselves asking.

Suppose we have a texture that looks like an up arrow.
],
box(width: 50%)[
#figure(
  image("screens/up_arrow.png", width: 75%, scaling: "pixelated", alt: "an image of an arrow pointing up"),
  numbering: none,
  caption: "This is a 64 by 64 texture, so we can see the texels."
)
])

== Our first goal

Let's just draw the arrow, but instead of a triangle, let's draw it to a quad, instead.

That means we will need to specify 6 vertices #footnote[There's a way to specify a quad with 4 verts using a different topology, but we haven't covered those yet.], two triangles.

== What are the U/V coordinates for each vertex?

#let left = figure(
  numbering: none,
  caption: text(20pt)[The texture, with the corner UV coordinates labelled. These are always the same for every texture.],
  alt: "top left is (0, 0), top right is (1, 0), bottom left is (0, 1), bottom right is (1, 1)",
  canvas(length: 8cm, {
    import draw: *;
    
    set-viewport((0, 0), (1, 1), bounds: (1, -1))

    rect((0, 0), (1, 1))
    content((0, 0), (1, 1), auto-scale: true, image("screens/up_arrow.png", fit: "stretch", width: 100%, height: 100%))

    content((-.15, 0), [(0, 0)])
    content((1.15, 0), [(1, 0)])
    content((-.15, 1), [(0, 1)])
    content((1.15, 1), [(1, 1)])
  })
)

#let right = figure(
  numbering: none,
  alt: "A rectangle composed of two triangles, with the diagonal of both going from the bottom left to the top right. Each vertex is labeled with question marks to indicate that we want to determine the 'u' 'v' coordinates.",
  canvas(length: 8cm, {
    import draw: *;

    set-viewport((0, 0), (1, 1), bounds: (1, -1))
    rect((0, 0), (1, 1))
    circle((0, 0), radius: 0.03, fill: yellow);
    circle((1, 0), radius: 0.03, fill: red);
    circle((0, 1), radius: 0.03, fill: red);
    circle((1, 1), radius: 0.03, fill: yellow);
  
    line((0, 1), (1, 0))

    content((-.15, 0), [(?, ?)])
    content((1.15, 0), [(?, ?)])
    content((-.15, 1), [(?, ?)])
    content((1.15, 1), [(?, ?)])
  }),

  caption: text(20pt)[The top right and bottom left points are duplicated between both triangles, but we want them to have the same U/V coordinates (otherwise there'd be a seam)],
)

#stack(dir: ltr, spacing: 4%,
  box(width: 48%, left),
  box(width: 48%, right)
)


== U/V coordinate answer

#figure(
numbering: none,
alt: "A rectangle composed of two triangles, with the diagonal of both going from the bottom left to the top right. Each vertex is labeled with question marks to indicate that we want to determine the 'u' 'v' coordinates.",
canvas(length: 8cm, {
  import draw: *;

  set-viewport((0, 0), (1, 1), bounds: (1, -1))
  rect((0, 0), (1, 1))
  circle((0, 0), radius: 0.03, fill: yellow);
  circle((1, 0), radius: 0.03, fill: red);
  circle((0, 1), radius: 0.03, fill: red);
  circle((1, 1), radius: 0.03, fill: yellow);

  line((0, 1), (1, 0))

  content((-.15, 0), [(0, 0)])
  content((1.3, 0), [(1, 0); (1, 0)])
  content((-.3, 1), [(0, 1); (0, 1)])
  content((1.15, 1), [(1, 1)])
}),
caption: "It's the same. We map the top left of the texture to the top left of the quad. We map the top right of the texture to both vertices in the top right. Ditto for bottom left. We map bottom-right to bottom-right."
)

== The principle

The basic idea when answering this question is: "what part of the texture do I want to be at this point on the triangle."

So let's make it a bit harder. How do we map the triangle _sideways_?

Specifically, we want the arrow to be pointing to the right. This means we need a new batch of U/V coordinates. Which ones?

== Right arrow mapping question?

#let left = figure(
  numbering: none,
  caption: text(20pt)[The texture, with the corner UV coordinates labelled. These are always the same for every texture.],
  alt: "top left is (0, 0), top right is (1, 0), bottom left is (0, 1), bottom right is (1, 1)",
  canvas(length: 8cm, {
    import draw: *;
    
    set-viewport((0, 0), (1, 1), bounds: (1, -1))

    rect((0, 0), (1, 1))
    content((0, 0), (1, 1), auto-scale: true, image("screens/up_arrow.png", fit: "stretch", width: 100%, height: 100%))

    content((-.15, 0), [(0, 0)])
    content((1.15, 0), [(1, 0)])
    content((-.15, 1), [(0, 1)])
    content((1.15, 1), [(1, 1)])
  })
)

#let right = figure(
  numbering: none,
  alt: "A rectangle composed of two triangles, with a right arrow superimposed.",
  canvas(length: 8cm, {
    import draw: *;

    set-viewport((0, 0), (1, 1), bounds: (1, -1))

    content((0, 0), (1, 1), angle: -90deg,
      image("screens/up_arrow.png", width: 100%))
  
    rect((0, 0), (1, 1))
    circle((0, 0), radius: 0.03, fill: yellow);
    circle((1, 0), radius: 0.03, fill: red);
    circle((0, 1), radius: 0.03, fill: red);
    circle((1, 1), radius: 0.03, fill: yellow);
    
    line((0, 1), (1, 0))

    content((-.15, 0), [(?, ?)])
    content((1.15, 0), [(?, ?)])
    content((-.15, 1), [(?, ?)])
    content((1.15, 1), [(?, ?)])
  }),

  caption: text(20pt)[Now we want the arrow to be pointing right.],
)

#stack(dir: ltr, spacing: 4%,
  box(width: 48%, left),
  box(width: 48%, right)
)

== Right arrow mapping answer

#let left = figure(
  numbering: none,
  caption: text(20pt)[Texture U/V coordinates are always the same. What changes is the U/V coordinates we use in the model, which can rotate, shift, or otherwise warp the texture.],
  alt: "top left is (0, 0), top right is (1, 0), bottom left is (0, 1), bottom right is (1, 1)",
  canvas(length: 8cm, {
    import draw: *;
    
    set-viewport((0, 0), (1, 1), bounds: (1, -1))

    rect((0, 0), (1, 1))
    content((0, 0), (1, 1), auto-scale: true, image("screens/up_arrow.png", fit: "stretch", width: 100%, height: 100%))

    content((-.15, 0), [(0, 0)])
    content((1.15, 0), [(1, 0)])
    content((-.15, 1), [(0, 1)])
    content((1.15, 1), [(1, 1)])
  })
)

#let right = figure(
  numbering: none,
  alt: "A rectangle composed of two triangles, with a right arrow superimposed.",
  canvas(length: 8cm, {
    import draw: *;

    set-viewport((0, 0), (1, 1), bounds: (1, -1))

    content((0, 0), (1, 1), angle: -90deg,
      image("screens/up_arrow.png", width: 100%))
  
    rect((0, 0), (1, 1))
    circle((0, 0), radius: 0.03, fill: yellow);
    circle((1, 0), radius: 0.03, fill: red);
    circle((0, 1), radius: 0.03, fill: red);
    circle((1, 1), radius: 0.03, fill: yellow);
    
    // line((0, 1), (1, 0))

    content((-.15, 0), [(0, 1)])
    content((1.15, 0), [(0, 0)])
    content((-.15, 1), [(1, 1)])
    content((1.15, 1), [(1, 0)])
  }),

  caption: text(20pt)[We make the top right U/V coordinate (0, 0) so that it pulls from the top left of the texture. We make the bottom right (1, 0), and so on for the other two..],
)

#stack(dir: ltr, spacing: 4%,
  box(width: 48%, left),
  box(width: 48%, right)
)


#place(top, curve(
  stroke: black,
  fill: none,
  curve.move((65pt, 68pt)),
  curve.cubic((100pt, 30pt), (500pt, 30pt), (680pt, 68pt)),
  curve.line((660pt, 52pt)),
  curve.move((680pt, 68pt)),
  curve.line((660pt, 78pt))
))

#place(top, curve(
  curve.move((292pt, 67pt)),
  curve.cubic((350pt, 50pt), (1000pt, -200pt), (680pt, 295pt)),
  curve.line((675pt, 280pt)),
  curve.move((680pt, 295pt)),
  curve.line((695pt, 290pt))
))

== How are we doing?

Can we see how this system allows us the flexibility to map the texture however we want?

The idea is that at each vertex, we're choosing what part of the texture we're pulling from.

The GPU will interpolate between the U/V coordinates of the vertices.

Think of the triangle as a cookie-cutter that can be stretched, moved, rotated, or sheared however you want. Think of the texture as the cookie dough. 

Feel free to ask questions. Then, let's do one more...

== Last UV mapping question

Now let's suppose we want to map this arrow so that it is facing right, and centered within our right triangle. We can add vertices if we want.

#let right_arrow_in_triangle = canvas(length: 8cm, {
  import draw: *;

  set-viewport((0, 0), (1, 1), bounds: (1, -1))
  
  content((0.5, 0.5), (1, 1), auto-scale: true, image("screens/up_arrow.png", width: 100%), angle: -90deg)

  let points = (
    (0, 1),
    (1, 0),
    (1, 1),
    (.5, .5),
    (.5, 1),
    (1, .5),
  );

  line(..points.slice(0, 3), close: true)
  
  for point in points {
    circle(point, radius: 0.02, fill: yellow)
  }
})

#stack(dir: ltr,
box(width: 50%)[
  #figure(
    caption: [What we have],
    numbering: none,
    image("screens/up_arrow.png", height: 60%, scaling: "pixelated", alt: "the up-arrow texture")
  )
],
box(width: 50%)[
  #figure(
    caption: [What we want],
    numbering: none,
    alt: "a diagram of a right triangle with the texture rotated right and placed within it",
    right_arrow_in_triangle
  )
]
)

== Any ideas?

Some additional things to keep in mind:
- Not every point has to sample the texture. We can use special U/V coordinates that says "just make this vertex blank"
- However, in our case, most of our texture is blank, so a U/V of (0, 0) would end up not drawing anything by itself (if it interpolates to another nearby U/V there would be only white pixels in between)
- Two vertices can be in the same location but have different U/V coordinates. Each vertex gets to have its own attribute values.

== One solution 

One way to do this is to keep the original triangle, but add more vertices