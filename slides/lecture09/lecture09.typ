#set document(title: "Notes on Computer Graphics: Lecture 9")

#import "@preview/touying:0.7.4": *
#import themes.simple: *
#import "@preview/shadowed:0.3.0": shadow
#import "../util.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/cetz:0.5.2" as cetz: canvas, draw

#show link: set text(blue)
#show: slide-theme


#title-slide[
  = Computer Graphics: Lecture 9
  == The Matrix

  \
  \
  \
  \
  Slide Deck © Grant Williams, 2026, License: #link("https://creativecommons.org/licenses/by-sa/4.0/deed.en")[CC-BY-SA 4.0] 
]

/*
+ Trig and linear algebra review:
  - Sin, cos, tan
  - Tau and turns
  - Pythagorean Theorem
  - Using what we know to draw a circle
  - Complex numbers (and quaternions mentioned?)
  - Dot products
  - Required viewing after: the 3blue1Brown video about matrices
+ 3d matrices
  - Basic affine transformations and their matrices
  - But what about translation?
  - Adding a dimension: homogeneous coordinates
  - Combining transformations
  - Projections 
  - Gl-matrix
  - Sending a matrix to the video card
  - Assignment: five perspective correct quads
  - bonus: make them textured using an atlas
  (maybe don't do perspective yet. not until we get to cameras anyway)
*/

== Welcome back!

Last time we reviewed the math we all forgot:
- We looked at the trig functions...
- ...and their inverses.
- The pythagorean theorem
- The dot product
- The cross product
- We saw some examples of when those things are handy in actual games or simulations.

== This time

This is the most important mathematical lesson we're going to have.

We're going to learn about matrices.

But we're not just going to review: we're going to show how they enable 3D operations.


== The matrix

So, okay. A matrix is a grid of numbers. Here's one:

#figure(
math.equation($mat(
  1, 0, 0;
  0, 2, 0;
  0, 0, 3;
)$,
alt: "A 3 by 3 matrix. The diagonal has the values 1, 2, and 3. Everything else is zero."
)
)

But what does a matrix actually represent, and what does the number of rows and columns tell us about it?

== Matrices are linear transformations

A matrix represents a function from vectors to vectors.

Specifically, they encode a linear function, where each componenent of the output is a *linear combination* of inputs.

What's a *linear combination*? It's a weighted sum.

So if we apply the function, each of the output values is treated as a weighted sum of the input values.

The rows of the matrix supply the weights.

== Example matrix

Consider this simple 2 by 2 matrix:
#math.equation($mat(
  1, 2; 3, 4
)$, alt: "the matrix 1, 2, 3, 4 from right to left, top to bottom")

This matrix encodes a function: f(v) = v', where `v'.x = v.x + 2*v.y` and `v'.y = 3*v.x + 4*v.y`.

Those are both weighted sums. 

To _call_ the function represented by a matrix, we post-multiply it by the column matrix we want to pass as input.

== Applying a matrix

For example, let's call that matrix on the vector `<5, 6>`

#math.equation($
  mat(1, 2; 3, 4) mat(5; 6) = mat(5 dot 1 + 6 dot 2; 5 dot 3 + 6 dot 4) = mat(17 ; 39)
$, alt:
  "multiplying the 1 2 3 4 matrix by the vector 5 6. The new x value is 5 times 1 plus 6 times 2. The new y value is 5 times 3 plus 6 times 4. The result is 17 39."
)

The columns provide a particularly good way to understand a matrix. Each column of a matrix is a *basis vector*. Each *basis vector* tells you how the matrix will transform the corresponding input component.

The basis vector `<1, 3>` above tells us that for every unit of `x` input, the output will move in the `<1, 3>` direction by one unit. So we moved 5 units in that direction, and 6 units in the `<2, 4>` direction.

== Why bother?

If you've tried to learn 3D graphics before, you probably were given a list of matrices. It's near the beginning of any 3D curriculum.

Why? Because there are a lot of things we want to do to our models: stretch them, squeeze them, rotate them, move them around, look at them in a camera, project the camera into perspective.

All of these things can be done with matrices (assuming we're in a projective space, which I will talk about later).

== Why bother? (2)

But more importantly: those things can all be done _in sequence_ with a single matrix. One matrix can represent _every sequence of any one_ of these actions.

We can stretch, squeeze, rotate, move, view, and project, in one single operation. 

In fact, we can stretch three times, then move, then stretch again.

That sequence of actions will have _one_ corresponding matrix.

== Why bother? (3)

Therefore, it's wonderful for computer graphics: we don't need to submit a list of actions to the video card. A single matrix suffices.

Granted, there is more than one _kind_ of thing that needs to be transformed. In practice, there will usually be several matrices that the video card sees:
- One for the model (stretching, squashing, moving, rotating)
- One for the camera (viewing)
- One for the projection (perspective, can be combined with camera)
- One for each animation bone (when using skeletal animations)
- Lights can use matrices, too.

#focus-slide("Questions?")

== Matrix sizes

A matrix does not have to be square.

The number of columns of a matrix tells you how many components the input vector must have.

The number of rows tells you have many ouput components the matrix will have.

If a matrix has fewer rows than columns, the matrix is necessarily cutting away dimensions. 

Likewise, if a matrix has more rows than columns, the matrix is necessarily adding dimensions.

== Matrix sizes (2)

However, our matrices will be square. A square matrix results in the same number of components of output as input.

Since we're working in 3D, let's start with a 3x3 matrix and see how far that gets us. 

Each matrix will represent an operation that we want to do, such as rotation. To use the matrix, we will multiply it by all the vertex positions in the model.

Assume the model will be centered, and that these operations happen around the origin.

== The scaling matrix 

One of the simplest matrices is the scaling matrix. It can be used to stretch and squeeze a 3D model when we apply it to the vertices.

#figure(
  math.equation($mat(
    1, 0, 0; 0, 2, 0; 0, 0, 3
  )$,
  alt: "The 1 2 3 diagonal matrix from earlier."
  )
)

This matrix will keep the x component the same. The y component will double, and the z component will triple.

So if we applied this matrix to `<2, 2, 2>` we would get `<2, 4, 6>`

All the vertices of the model are pushed away (or pulled toward for values less than 1) zero.

== The identity matrix

If we "scale" every component by 1, then nothing will change. This is the identity matrix. It is the matrix equivalent of 1. Multiply a compatible vector by it: nothing happens.

#figure(
  math.equation($
    mat(1, 0, 0; 0, 1, 0; 0, 0, 1)
  $, alt: "The identity matrix, 1s along the diagonal, and zeros everywhere else.")
)

When is this one useful? It's very useful for debugging: set the current model's matrix to the identity and it should be hanging out the origin, looking the same as it looked in the 3D modelling program.

== The rotation matrix

This is the first one that requires some explanation.

Let's start by figuring out how it works in 2D.

If we want to rotate a _point_ in 2D. How do we do it?

E.g., let's say we have the point described by the vector `<1, 1>`. How do we rotate that by, say, 10% of a turn around the origin?

== Rotation in 2D

Let's break it down by component.

Imagine that we rotated just the x axis.

The new value of the axis was pointing at (1, 0). Now it will point to #math.equation($(cos(theta), sin(theta))$, alt: "cos theta, sin theta").

The new y axis is going to be rotated the same amount, but 25%#sym.tau forward: (cos(theta + 25%#sym.tau), sin(theta + 25%#sym.tau)

This results in #math.equation($-sin(theta), cos(theta)$, alt: "minus sine theta, coss theta") to be the new y-axis.

But what do we do with these new axes?

== Rotation in 2D (2)

We take the old x value and multiply it by the new x-axis. That stretched x axis is part of the answer.

We take the old y value and multiply it by the new y-axis. That stretched y axis is the other part of our answer.

We add those two parts together.

I've just described matrix multiplication by this matrix:

#figure(
  math.equation($mat(
    cos(theta), -sin(theta) ; sin(theta), cos(theta)
  )$, alt: "matrix with the following basis vectors. x: coss theta, sine theta. y: minus sine theta, coss theta.")
)

== Rotation in 2D--basis vector version
But it's easier to understand if we think about it as basis vectors.

A 2x2 matrix is just two independent axes: one x, one y.

Rotate _both_ of them by theta.

The new matrix just has the basis vectors pointing in the rotated direction:

#figure(
  alt: "a diagram showing a standard x-y coordinate plane, but with the axes rotated counter-clockwise by .10 turns.",
  canvas(length: 5cm, {
    import draw: *;

    set-viewport((0, 0), (1, 1))

    let theta = .1 * calc.tau

    let newX = (calc.cos(theta), calc.sin(theta))
    let newY = (-calc.sin(theta), calc.cos(theta))

    line((0, 0), (1, 0), mark: (end: (symbol: "straight")))
    line((0, 0), (0, 1), mark: (end: (symbol: "straight")))
    line((0, 0), newX, stroke: (dash: "dashed"), mark: (end: (symbol: "straight")))
    line((0, 0), newY, stroke: (dash: "dashed"), mark: (end: (symbol: "straight")))

    content((.75, .1), [old x])
    content((1.1, .6), [new x])
    content((.3, .9), [old y])
    content((-.7, .5), [new y])
  })
)

== Rotation about Z in 3D
It turns out, if we want to rotate within the X-Y plane like that, in three dimensions it's exactly the same, except we ignore the z axis. That is, the z axis stays the same:

#figure(
  numbering: none,
  math.equation($mat(
    cos theta, -sin theta, 0; sin theta, cos theta, 0; 0, 0, 1
  )$, alt:"the same rotation matrix, except the z column is just 0, 0, 1, and the bottom row is 0, 0, 1"),
  caption: [The rotation matrix around the Z-axis. ]
)

But what if we want to rotate around the X or Y axes?

== Rotation about X or Y in 3D

The axis we're rotating around doesn't change. It gets "passed through".

Here is rotation around X:

#figure(
  math.equation($mat(
    1, 0, 0;
    0, cos theta, -sin theta;
    0, sin theta, cos theta
  )$, alt: "rotation about the x-axis. The first column is 1 0 0. The second is 0, coss theta, sine theta. The third is 0, minus sine theta, minus coss theta.")
)

Here is rotation around Y#footnote[The signs on the sines are flipped because Z comes _out_ of the screen, so the relationship between Z and X are opposite the relationship between X and Y.]:
#figure(
  math.equation($mat(
    cos theta, 0, sin theta;
    0, 1, 0;
    -sin theta, 0, cos theta;
  )$),
  alt: "rotation about the y-axis. The first column is coss theta, 0, minus sine theta; the second column is 0, 1, 0; the third column is sine theta, 0, coss theta."
)

== Handedness of coordinate systems

Just a quick aside: I mentioned that the Z-coordinate comes _out_ of the screen, and the relationship between Z and X is what caused the signs to be flipped on some of the coefficients.

Z doesn't have to come out of the screen. If it does, we say that the coordinate system is *right-handed*.

If Z goes _into_ the screen, the coordinate system is *left-handed*.

== Handedness of coordinate systems (2)

Hold your left hand up and make an "L". Poke your middle finger forward. Your middle finger is "+Z", your thumb is "+X", and your index finger is "+Y".

Hold your right hand up with your thumb and index finger going the same way. You will have to twist it around. Z (your middle finger) will point toward you.

#stack(dir: ltr,
  figure(
    numbering: none,
    caption: text(20pt)[Left handed],
    alt: "Z points into the screen, x and y point left and up respecively.",

    canvas(length: 3cm, {
      import draw: *;

      set-viewport((0, 0), (1, 1))
      line((0, 0), (1, 0))
      line((0, 0), (0, 1))
      line((0, 0), (.5, .5))
      content((0.1, 1), [y])
    })
  )
)


== Handedness of coordinate systems (3)

The depth buffer in WebGPU is actually left-handed: larger Z values are considered behind smaller ones, so Z goes into the screen.


== Affine matrices


== Swizzling