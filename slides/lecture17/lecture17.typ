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

That's not ideal. It ends up with the point distribution being uneven, as you can maybe see.

However, it turns out that this is a great way of creating a sphere. Keep it in mind!

Speaking of spheres, let's talk about how to make those!

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



 
