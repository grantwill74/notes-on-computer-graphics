#set document(title: "Notes on Computer Graphics: Lecture 17")

#import "@preview/touying:0.7.4": *
#import themes.simple: *
#import "@preview/shadowed:0.3.0": shadow
#import "../util.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/cetz:0.5.2" as cetz: canvas, draw

#show link: set text(blue)
#show: slide-theme


#title-slide[
  = Computer Graphics: Lecture 17
  == Spheres, Cube-maps, and Skyboxes

  \
  \
  \
  \
  Slide Deck © Grant Williams, 2026, License: #link("https://creativecommons.org/licenses/by-sa/4.0/deed.en")[CC-BY-SA 4.0] 
]


== Welcome back!

Last time we learned the whole Phong model

We learned how to draw not only directional lights, but point lights as well. [what's the difference?]

We also learned about storing structs in WGSL, how it can help  organize the software design of our shaders but how it also requires understanding _alignment_. [how does alignment work?]

== This time 

We're going to learn about generating spheres.

Really? That's all?

That's all...but it's a bit more challenging than you think.

We're also going to learn a new texturing technique: the cube map. Finally: no more duplicating the UV coordinates on a cube.

Cube mapping isn't just useful for texture mapping cubes: it's great for spheres, too, and it even enables some cool features such as skyboxes and environment maps (shiny textures that reflect the environment).

== Spheres

Okay, this is a geometry pop quiz. If you had to generate a sphere mesh _right now_, what would you do?

[Let's think about this as a class.]

== Circles 

Chances are, learning to generate a circle will help us understand how to generate a sphere.

So let's start with generating a circle.

Ultimately, our video card wants to draw triangles. It is technically possible to use fancy tesselation shaders to generate a circle that is visually perfect (i.e., at a given resolution it is impossible to tell it from an ideal circle). 

But let's not worry about that now. Let's just generate a regular polygon with a lot of sides that we will interpret as a circle if it has enough sides.

== Circles (2)

The most straightforward way to generate a circle is to first decide how many sides we want. Say, 100. Then, plot that many points in the right place.

```ts
const verts = []; // vertex data: x,y coordinates
const nPoints = 100;

for (let point = 0; point < nPoints; point++) {
    ...
}
```

So...[how do we know where a point goes? What are its coordinates?]

== Circles (3)

These points are going to go around the circle. Over the course of this process, the points will complete a single turn.

That means, the first point will start at 0 turns, the second will then be at one hundredth of a turn, the third will be two hundredths, etc.

So, we can determine the number of turns like this:

```ts
for (let point = 0; point < nPoints; point++) {
    const turns = point / nPoints; 
}
```

But that's not enough. How do we turn _turns_ into XY coordinates?

== Circles (4)

First we need to convert them into angles in radians. Then we can use sine and cosine on the radians:

```ts
for (let point = 0; point < nPoints; point++) {
    const turns = point / nPoints;
    const rads = turns * TAU;
    const x = Math.cos(rads);
    const y = Math.sin(rads);
    verts.push(x, y);
}
```

== Circles (5)

#let nPoints = 20
#let circlePoints = ();

I coded the software renderer in my slides software to follow this algorithm using #nPoints vertices. It's pretty close to a circle.

#figure(
  canvas(length: 2cm, {
    import draw: *;

    set-viewport((-1, -1), (1, 1))

    for point in range(nPoints) {
      let turns = point / nPoints;
      let rads = turns * calc.tau;
      let x = calc.cos(rads);
      let y = calc.sin(rads);
      circlePoints.push((x, y))
      circle((x, y), radius: 0.02, fill: black)
    }

  }),
  alt: "figure of vertices arranged as the points of a regular polygon, approximating a circle.",
)

== Circles (6)

But a mesh isn't just a collection of points. It's also a collection of faces! (i.e., triangles). So how can we stitch our mesh together into triangles?

You might think we need to put a vertex in the center like this:

#figure(
  canvas(length: 2cm, {
    import draw: *;

    set-viewport((-1, -1), (1, 1))

    for point in circlePoints {
      circle(point, radius: 0.02, fill: black)
    }
    circle((0, 0), radius: 0.02, fill: black)
  }),
  alt: "the previous figure now has a point in the center of the circle.",
)

== Circles (7)

Then, we can stitch together a circle by creating triangles that pass through the center...

#figure(
  canvas(length: 2cm, {
    import draw: *;

    set-viewport((-1, -1), (1, 1))

    for point in circlePoints {
      circle(point, radius: 0.02, fill: black)
    }
    circle((0, 0), radius: 0.02, fill: black)
    line((0, 0), ..circlePoints.slice(0, 2), fill: green, close: true)
  }),
  alt: "A triangle has been drawn between two adjacent points on the arc of the circle through the center point.",
  caption: [I.e., do this for all 20 slices.],
  numbering: none,
)

== Circles (8)

However, there is another way, where we just use one of the points on the side as the start of the triangle.

#figure(
  canvas(length: 2cm, {
    import draw: *;

    set-viewport((-1, -1), (1, 1))

    for point in circlePoints {
      circle(point, radius: 0.02, fill: black)
    }
    
    for i in range(1, nPoints - 1) {
      line(circlePoints.at(0), ..circlePoints.slice(i, i + 2), close: true, fill: green);
    }
  }),
  alt: "A triangle has been drawn between every pair of adjacent points and the first point. This fills the circle without needing a center point",
  caption: [This saves a whole vertex #emoji.face.wow. Despite looking weird, it's just as good.],
  numbering: none,
)

== Triangle fans

There's a name for this kind of topology: a triangle fan.

It was built into legacy graphics APIs like OpenGL.

The first index in the strip would be the shared vertex, and then the other indices would be specified in the winding order. [0, 1, 2, 3, ...]

#figure(
  [
    #box([
      #image("screens/tick_tock_clock.jpg", height: 40%, alt: "a screenshot of a pendulum in a video game.");
      #place(bottom + center, game-name([Super Mario 64]))
    ])
  ],
  caption: text(18pt)[The pendulum's disc in Tick tock clock was a triangle fan.],
  numbering: none
)

== Triangle fans (2)

Triangle fans were useful because you could generate any convex polygon from them. As long as the polygon was convex, you could use any point as the "center" point.

The screenshot before used the west most point in the disc.

However, WebGPU does not support triangle fans.

The reason is that it's actually possible to use a triangle strip anywhere you would use a triangle fan, with the same number of indices.

[can anyone think of how to do it?]

== Triangle fans (3)


#figure(
  canvas(length: 2cm, {
    import draw: *;

    set-viewport((-1, -1), (1, 1))

    for point in circlePoints {
      circle(point, radius: 0.02, fill: black)
    }
    
    for i in range(0, calc.ceil(nPoints / 2)) {
      let a = circlePoints.at(i);
      let b = circlePoints.at(i + 1);
      let c = circlePoints.at(nPoints - i - 1);
      let d = circlePoints.at(nPoints - i - 2);
      line(a, b, c, close: true, fill: green);
      line(b, c, d, close: true, fill: green);
    }
  }),
  alt: "imagine that we start with the eastmost point (0) and build a triangle strip by zigzagging up to point 1, then down to point 19, then up to 2, then down to 18, etc.",
  caption: [This saves a whole vertex and requires exactly as many indices as vertices! Just as good as a fan. [0, 1, 19, 2, 18, ...]],
  numbering: none,
)

== Circles: more ways 

#let nSquarePoints = 28
#let squarePointsPerSide = calc.ceil(nSquarePoints / 4)
#let sidePoints = range(0, squarePointsPerSide).map((x) => 2 * x / (squarePointsPerSide - 1) - 1)
#let squarePoints = ();

#{
  for i in range(squarePointsPerSide) {
      let p = sidePoints.at(i);
      squarePoints.push((p, 1));  // top
      squarePoints.push((p, -1)); // bottom
      squarePoints.push((-1, p)); // left
      squarePoints.push((1, p));  // right
  }
}

There are actually several ways to generate circles. We can even start with a square and smoosh the points into a circle by normalizing them:

#place(center + bottom, dy: 5%, stack(dir: ltr, spacing: 5%,
figure(
  canvas(length: 2cm, {
    import draw: *;
    set-viewport((-1, -1), (1, 1))

    for p in squarePoints {
      circle(p, radius: 0.02, fill: black)
    }
  }),
  caption: [Before],
  numbering: none,
  alt: "A square shape formed out of points around the edges"
),
figure(
  canvas(length: 2cm, {
    import draw: *;
    set-viewport((-1, -1), (1, 1))

    for p in squarePoints {
      let (x, y) = p
      let l = calc.sqrt(x * x + y * y)
      circle((x / l, y / l), radius: 0.02, fill: black)
    }
  }),
  caption: [After],
  numbering: none,
  alt: "A circle formed by taking the square points and normalizing each one as if it were a vector, moving it towards the center of the square and being one unit long."
)
))

== Circles: more ways

It works because a circle is a shape were every point on it has the same distance from the center. Assuming the center is 0, if we normalize all the points, the circle will have a radius of 1.

It's also not ideal. It ends up with the point distribution being uneven, as you can maybe see. We'd like the vertices to be spread more evenly.

However, it turns out that this is a great way of creating a sphere. It's called a cube sphere, and it's the _second_ sphere algorithm we're going to learn today. Keep it in mind!

But first...

#focus-slide("Questions?");

== Now spheres

Let's try to extend our algorithm for making circles.

Imagine that we made the equator of a large sphere that way. 

Could we imagine how to stack more rings around the equator?

This kind of sphere is called a *UV-sphere*, because it's easy to compute the UV coordinates of its vertices.

[But how do we build one?]

== UV-spheres

UV spheres are built out of rings, like the ones we generated earlier.

Only, we don't fill these rings into circles. We'll see how to tesselate them later.

#let ring0 = circlePoints.map(((x, y)) => (x, 0, y));
#let ring1_unnormalized = ring0.map(((x, y, z)) => (x, y + .2, z))

#figure(
  canvas(length: 2cm, {
    import draw: *;

    set-viewport((-1, -1), (1, 1))
    perspective(x: 35deg, z: 0, {
      line(..ring0, close: true)
      line(..ring1_unnormalized, close: true)
    })
  }),
  alt: "two rings, generated using the first algorithm we looked at, but without being filled in with triangles. One is stacked on top of the other."
)

Here are two rings. Assume the bottom is the equator. How do we shrink the top one to make it start to curve like the top of a sphere?

== UV-spheres (2)

Let's imagine a vertical cross section. What we want is the cosine of the angle between two layers in the sphere:

#figure(
  canvas(length: 1.5cm, {
    import draw: *;

    set-viewport((-1, -1), (1, 1))
    circle((0, 0), radius: 1)

    line((0, 0), (0.8, 0), (0.8, calc.sin(calc.acos(.8))), close: true)
    content((0.25, -.15), text(20pt)[cos(#math.theta)])
    content((0.18, 0.06), text(20pt)[#math.theta])
  }),
  alt: "A unit circle with a triangle inscribed. Theta is the inner angle of the triangle, and its horizontal leg is labled cos theta."
)

We can choose the angle of the height of the ring, or generate it. Either way the cosine of that angle is the radius of the ring.

== UV-spheres (3)

And the y value is the sine of the angle.

Let's stack 3 rings for good measure:

#let ring1_theta = calc.tau / 20

#let rings = (ring0,)

#for i in range(1, 6) {
  let ring_i = ring0.map(
    ((x, y, z)) => {
    let r = calc.cos(ring1_theta * i);
    let y = calc.sin(ring1_theta * i);
    (x * r, y, z * r)
  });

  rings.push(ring_i);
}

#let ring1 = rings.at(1)
#let ring2 = rings.at(2)


#figure(
  canvas(length: 2cm, {
    import draw: *;

    set-viewport((-1, -1), (1, 1))
    perspective(x: 35deg, z: 0, {
      line(..ring0, close: true)
      line(..ring1, close: true)
      line(..ring2, close: true)
    })
  }),
  alt: "three rings which are starting to form the upper hemisphere of a sphere"
)

Hopefully we see the upper hemisphere start to form. But how do we form the triangles?

== UV-spheres (4)

We pair adjacent rings together into strips. Then, we can draw a triangle strip all around the sphere. Here are some triangles: this pattern repeats:

#figure(
  canvas(length: 2cm, {
    import draw: *;

    set-viewport((-1, -1), (1, 1))
    perspective(x: 35deg, z: 0, {
      line(..ring0, close: true)
      line(..ring1, close: true)
      line(..ring2, close: true)

      // upper triangle
      for i in range(2, 5) {
        line(ring0.at(i), ring0.at(i + 1), ring1.at(i), close: true, fill:blue)
      }

      // lower triangle
      for i in range(2, 5) {
        line(ring1.at(i), ring0.at(i + 1), ring1.at(i + 1), close: true, fill: blue)
      }
    })
  }),
  alt: "A partial triangle strip made from the bottom ring"
)

We can draw the strip several ways. For example, if the points go clockwise: [0, pointsPerRing, 1, pointsPerRing + 1, 2, ...]

== UV-spheres (5)

But what happens when we get to the top?

That's where it gets gnarly: you might think we'd put a single vertex at the top but we can't. Remember that these vertices need to have not only XYZ coordinates, but also UV.

If the top ring were connected to a single point, they'd all have to share the same UV coordinate, which would warp the texture.

Instead we create an infinitely small ring at the very top. This allows each point in this ring to have a different UV coordinate, but also means that the top of the mesh is sealed (we say it's a #link("https://davidstutz.de/a-formal-definition-of-watertight-meshes/", "watertight") mesh)

== UV-spheres (6)

#figure(
  canvas(length: 2cm, {
    import draw: *;

    let pointsInRing = ring0.len();

    set-viewport((-1, -1), (1, 1))
    perspective(x: 35deg, z: 0, {
      for ring in rings {
        line(..ring, close: true);
      }

      for ring in rings.slice(1) {
        let mirrored = ring.map(((x, y, z)) => (x, -y, z));
        line(..mirrored, close: true);
      }

      let secondTop = rings.at(rings.len() - 2);
      let top = rings.at(rings.len() - 1);
      for i in range(pointsInRing) {
        let j = calc.rem(i + 1, pointsInRing)
        line(secondTop.at(i), top.at(i), secondTop.at(j), closed: true, fill: green)
        // line(secondTop.at(j), top.at(i), top.at(j), closed: true, fill: green);
      }
      line(top.at(0), secondTop.at(0), top.at(1), fill: green, closed: true);
    });
  }),
  alt: "UV-sphere, where the space between the top two rings is filled in with triangles.",
  caption: text(22pt)[Following the same triangle strip, half of our triangles are degenerate, because two adjacent points on the top ring are infinitely close together. You can special-case this if you want a slightly more optimized mesh.],
  numbering: none,
)

== Finished UV-sphere

#figure(
  image("screens/uv_sphere_wireframe.png", height: 70%, alt: "UV-sphere screenshot"),
  caption: [A wireframe UV-sphere generated using the algorithm we've discussed. See `sample14` for code.],
  numbering: none,
)

== UV-spheres (7)

So far we've talked about how to generate rings out of vertices with known XYZ coordinates, and how to stitch those rings together into layers using indices. But what about UV coordinates? 

The main point of UV spheres is that we want to wrap a single texture around them. So we want the U coordinate to increase as it goes around a latitude, and we want the V coordinate to increase as it goes toward the bottom pole.

So, [how can we compute UV coordinates?]

== UV-spheres (8)

For a given ring, we can make the U coordinate of the first vertex 0. We want the last vertex to have a U coordinate of 1, and for it _to overlap the first vertex_.

#figure(
  canvas(length: 2cm, {
    import draw: *;

    set-viewport((-1, -1), (1, 1))
    perspective(x: 35deg, z: 0, {
      line(..ring0, close: true)

      circle(ring0.at(0), radius: 0.04, fill: black)
      content(ring0.at(0), anchor: "west", [u = 0, u = 1])
      circle(ring0.at(10), radius: 0.04, fill: green)
      content(ring0.at(10), anchor: "east", [u = 0.5])
      circle(ring0.at(15), radius: 0.04, fill: blue)
      content(ring0.at(15), anchor: "west", [u = 0.75])
      circle(ring0.at(5), radius: 0.04, fill: blue)
      content(ring0.at(5), anchor: "east", [u = 0.25])
    })
  }),
  alt: "A single ring. The first and the last vertex overlap, one has a U of 0, the other a U of 1. The point with U = 0.5 is on the opposite side of the ring. There are two points in between, one on the left side of the sphere with U = 0.25, on directly opposite that point with U = 0.75."
)

In general, the `i`th point will have a U coordinate of `i / (numberOfPoints - 1)`, where `numberOfPoints` includes the last point that overlaps the first one.

== UV-spheres (9)

But what about the V coordinate. We want the V coordinate to increase as the y value goes _down_ (because remember, a V of 0 means the top of the texture).

[Any ideas?]

== UV-spheres (10)

The simplest approach is, for ring number `i`, to just let `v = i / (num_rings - 1)`. This is assuming you're building the mesh from top to bottom.#footnote[some textures are distorted so that they are "squeezed" around the poles to counteract the fact that the y distance between rings is not constant. You can use the vertical angle of the ring and scale it to the range [0, 1] for these textures.]

If you're going from bottom to top (so `i = numRings - 1` at the top ring), take the complement: `v = 1 - i / (num_rings - 1)`.

Alternatively, you can use an already-computed y component: `v = y * 0.5 + 0.5`. y normally ranges from -1 to 1, so this squeezes it into the range 0 to 1.

#focus-slide("Questions?")

== UV-sphere problems

UV-spheres are a very simple way to draw a sphere with a texture painted over it. `sample14` shows how that can be used to draw a globe (the UV-sphere is on the left).

They aren't an ideal topology, however, and they are typically only used when we want to wrap a cylindrical texture.

[Can anyone think of a problem with them?]

== UV-sphere problems (2)

There are really two issues with UV-spheres:
+ Poor point regularity: there are tons of points at the poles compared to the equator.
+ Texture distortion: as a result, the sphere has the lowest detail at the equator, where detail is often the most important!

To illustrate this, in the next slide, compare the wireframe of the UV-sphere to the wireframe of the next type of sphere we're going to learn...

== UV-sphere vs Cube-sphere

#stack(dir: ltr, spacing: 4%,
  box(width: 48%, figure(
      image("screens/uv_sphere_wireframe.png", alt: "wireframe of a UV-sphere"),
      caption: text(20pt)[A uv-sphere. Notice that the center faces are much larger than the ones near the top.],
      numbering: none
    )
  ),
  box(width: 48%, figure(
      image("screens/cube_sphere_wireframe.png", alt: "wireframe of a cube-sphere"),
      caption: text(20pt)[It's a little hard to tell, but this sphere's faces are much more evenly-sized.],
      numbering: none,
    )
  )
)  

== Introducing cube-spheres

Let's learn how to make *cube-spheres* next. They have several advantages over UV-spheres:
+ They have better vertex distribution#footnote[although still not perfect: that property belongs to *icospheres*]
+ They can be more evenly textured

First, let's see how to build a cube-sphere. Then, we'll learn a cool new texturing technique that is ideal for them called cube-mapping.#footnote[You can also use this technique on UV-spheres, but the texture will be sampled more unevenly, possibly causing minor distortion.]

== Building a cube sphere

Now it's time to build one. 

Remember earlier in the lecture when we built a circle by starting with a square and then squishing it into a circle.

But this time it will be _good_ instead of _bad_.

Wait...won't there still be distortion? Won't there be more points away from the faces of the cube?

Yes, but we're going to tolerate that, because it won't be as bad as the UV-sphere and it will texture better.

== Building a cube sphere (2)

Let's start with the front face.

We want to, given a number of subdivisions, create a grid of points in a square shape. We can use a basic 2D for loop pair for this.

For each point, we want to normalize it so that we pull it into a sphere.

That's it. If we do that for a whole square, we will have one-sixth of a cube sphere.

== Building a cube sphere (3)

```ts
const spanVerts = nFaceSubdivs + 1;
// front face, in the Z+ direction (right-handed)
for (let row = 0; row < spanVerts; row++) {
    for (let col = 0; col < spanVerts; col++) {
        const y = 2 * row / nFaceSubdivs - 1;
        const x = 2 * col / nFaceSubdivs - 1;
        const l = Math.sqrt(x * x + y * y + 1); // length
        // quiz: where does the 1 come from in the sqrt?
        // push the normalized coordinate:
        verts.push(x / l, y / l, 1 / l);
    }
}
```

== Building a cube sphere (4)

We do this for all six faces. The only wrinkle is making sure they all face _outward_ (be mindful of winding). 

But what about indices?

Believe it or not, that's actually easier than it was for the UV-sphere. We have a grid of points for each face. We just need to build a triangle strip.

The simplest way to do this is to build a "ribbon" going along each row...

== Building a cube sphere (5)

#let grid = ()
#let face = ()
#let cube_dim = 5;
#{
  for r in range(cube_dim) {
    let row = ()
    let face_row = ()
    let y = (r / cube_dim) * 2 - 1
    for c in range(cube_dim) {
      let x = (c / cube_dim) * 2 - 1
      row.push((x, y))
      
      let l = calc.sqrt(x * x + y * y + 1)
      face_row.push((x / l, y / l))
    }
    grid.push(row)
    face.push(face_row)
  }
}

#figure(
  canvas(length: 4cm, {
    import draw: *;

    set-viewport((-1, -1), (1, 1))
    perspective(x: 25deg, y: 30deg, z: 0, {
      for row in face {
        for p in row {
          circle(p, radius: 0.02)
        }
      }

      let row_a = face.at(2)
      let row_b = face.at(3)
      for i in range(cube_dim - 1) {
        line(row_a.at(i), row_b.at(i), row_b.at(i + 1), close: true, fill: blue);
        line(row_a.at(i), row_a.at(i + 1), row_b.at(i+1), fill: blue, close: true)
      }
    })
  }),
  alt: "a 5-by-5 grid of points. A single triangle strip has been drawn between the middle row and the row above it.",
  numbering: none,
  caption: [Here is one such ribbon. I've rotated the image in 3D slightly so you can see how how it bends inward.]
)

== Building a cube sphere (6)

So, a triangle strip might look like this:

== Building a cube sphere...UVs?