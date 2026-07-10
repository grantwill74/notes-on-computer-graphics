#set document(title: "Notes on Computer Graphics: Lecture 8")

#import "@preview/touying:0.7.4": *
#import themes.simple: *
#import "@preview/shadowed:0.3.0": shadow
#import "../util.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/cetz:0.5.2" as cetz: canvas, draw

#show link: set text(blue)
#show: slide-theme


#title-slide[
  = Computer Graphics: Lecture 8
  == The math we all forgot

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
*/

== Welcome Back!

Last time we learned about textures:
  - How they are stored
  - How they are sampled
  - How to create them
  - How to load them
  - How to put them in a bind group
  - How to make that bind group available to a shader
  - How to use `textureSample` in the shader.

== This time

We're going to review all the important math that we forgot:
  - #sym.pi and #sym.tau#footnote[You might not have learned this one but once you see how useful it is you'll wish you had!]
  - Trigonometric functions (especially `sin`, `cos`, `tan`, and inverses)
  - The Pythagorean theorem
  - The law of cosines
  - The dot product
  - Complex numbers and quaternions (brief)

"Oh, yuck." right?

== Not so fast

One of the reasons why math can be so challenging in school is that we often learn it way before we actually need it.

This is logical: math is useful no matter what, whether it be improving general problem-solving ability or describing a specific technique.

However, it makes it hard for us to force ourselves to do it unless there is a clear goal in sight.

I'm hoping that the same goals that drove you to take this class will help you want to learn these topics. I will pair each math topic with something it will help you do in a game or simulation!

== Dimensionality

You mainly learned trig in 2 dimensions.

It's kind of surprising that everything you learned pretty much works the same in 3.

The pythagorean theorem works in 3-dimensions, as does the dot product.

I'm going to be using 2-D exampls to keep things easy to illustrate, but just be aware: scaling up isn't a problem.

== Etymology

First of all, what does "trigonometry" mean. What are the Greek roots?

[class?]

== Etymology (2)

Ancient Greek:
- Trígōnon meant triangle
- Métron meant measure

So, trigonometry is measuring triangles.

Cool. Who cares? [Why are triangles important at all?]

== Why triangles are important

There are two ways that people frequently think of directions:
+ By grid reference: "go to D4" or "go 4 miles east and 3 down"
+ By angle + distance: "face southeast and go 5 miles"

The first one uses _rectangular coordinates_. That is, the coordinates are the lengths of sides of a rectangle with a known anchor point. 

The second uses _circular_ or _angular_ coordinates. They are described by an direction (angle) and a distance (radius), therefore defining a circle.

In games and simulations, we use both, often interchangeably. We want to position something in space, and rotate it to face a direction, ideally in one operation.

== Why triangles are important (2)

#let draw_circ_and_tri(x, y) = {
  import draw: *;

  circle((0, 0), radius: 1)
  line((0,0), (x, 0), (x, y), close: true)
}
#let x = calc.cos(30deg)
#let y = calc.sin(30deg)

#stack(dir: ltr, spacing: 4%,
box(width: 48%)[
Right triangles relate rectangles to circles.

That is, we can go back and forth from a pair of side lengths to an angle + radius.

The legs of the right triangle are the rectangular coordinates, and the inner angle and hypotenuse length are the circular coordinates.
],
box(width: 48%)[
  #figure(
    numbering: none,
    alt: "A diagram showing a circle with a right triangle superimposed in it. The hypotenuse of the triangle is the radius of the circle, labeled 'r'. The angle of the triangle and its legs are named 'theta', 'x', and 'y'.", 
    canvas(length: 3cm, {
      import draw: *;

      set-viewport((-1, -1), (1, 1))

      draw_circ_and_tri(x, y)

      content((x / 2, -.05), anchor: "west", [x])
      content((x - .05, y / 2), anchor: "east", [y])
      content((x / 2, y / 2 + .05), anchor: "south", [r])
      content((.20, .05), [#sym.theta])
    })
  )
]
)


== What even is an angle?

#stack(dir: ltr, spacing: 4%,
box(width: 48%)[
To me, the most straightforward definition of the measure of an angle, is that, for a sector of a triangle, the angle is the ratio of the arclength to the radius.

If the radius is 1, the distance around the outside is equivalent to the angle in radians.

That is: #math.equation($theta = "arc" / r$, alt: "theta equals arc over r")
],
[
#figure(
  alt: "A figure that shows two rays, labelled 'r', meeting at the center of a circle. The angle between them is labelled 'theta'. The arc length between them on the outside of the circle is labelled 'arc'.",
  canvas(length: 3cm, {
    import draw: *;
    set-viewport((-1, -1), (1, 1))

    circle((0, 0), radius: 1)
    line((0, 0), (x + .05, y + .05))
    line((0, 0), (1 + .07, 0))
    content((x / 2, -.05), anchor: "west", [r])
    content((1 + .2, y / 2), anchor: "east", [arc])
    content((x / 2, y / 2 + .05), anchor: "south", [r])
    content((.20, .05), [#sym.theta])
  })
)
]
)

== Measuring angles

#let degree = math.equation($(1/360)^"th"$, alt: "one three hundred sixtieth")
#let two_pi = math.equation($2 pi$, alt: "two pi") 

Angles are technically unitless (a distance over a distance), but we typically use a reference point to let the listener know how we wish to define the angle. 

The most common are degrees and radians.

A radian is a length of 1, but referring to an angle. So "1 but going around the outside of the circle". 

Because the unit circle has a circumference of #two_pi, a full rotation is #two_pi (radians). 

A degree is #degree of #two_pi., or #{2 * calc.pi / 360} radians

== Radians are awkward

It is an unfortunate historical fact that #sym.pi refers to the area of the unit circle rather than its circumference (which is #two_pi).

What if we defined a new symbol, #sym.tau, as being equal to #two_pi?

A rotation of #sym.tau means a full rotation around the circle. Therefore, we can define rotation in "turns" instead of radians or degrees.

For example, a rotation of #math.equation($40% tau$, alt: "forty percent tau") means 40% of the way around a circle. What is that in radians? #math.equation($.4 tau = .4 times 2 pi$, alt: "point 4 of tau equals point four times two pi"), which is 2.51ish. 

I prefer to define my rotations in turns. To convert to radians so you can use trig functions: multiply by #sym.tau.

== Converting from angular to rectangular

#stack(dir: ltr, spacing: 4%,
box(width: 50%)[
So, we have an angle, which, together with the radius, can define a specific point on the outside of the circle.

Let's make it the unit circle: now the radius is 1. 

How do we convert to rectangular coordinates?
],
box(width: 48%)[
  #figure(
    numbering: none,
    alt: "A right triangle within a circle. The internal angle is labelled 'theta'. The radius is 1. There are question marks where the legs are.", 
    canvas(length: 3cm, {
      import draw: *;

      set-viewport((-1, -1), (1, 1))

      draw_circ_and_tri(x, y)

      content((x / 2, -.07), anchor: "west", [?])
      content((x - .05, y / 2), anchor: "east", [?])
      content((x / 2, y / 2 + .05), anchor: "south", [1])
      content((.20, .05), [#sym.theta])
    })
  )
]
)

== Converting from angular to rectangular (2)

#stack(dir: ltr, spacing: 4%,
box(width: 48%)[
This is what sine and cosine are for.

The sine of an angle is the length of the y leg.

The cosine is the x leg's length.

They are defined assuming a hypotenuse of 1, so if the circle is not a unit circle, we scale the lengths by the hypotenuse.
],
box(width: 48%)[
  #figure(
    numbering: none,
    alt: "The same diagram, but the bottom leg is labeled 'cos theta' and the right leg is labeled 'sine theta'. The point described by the angle theta is therefore (cos theta, sine theta).", 
    canvas(length: 3cm, {
      import draw: *;

      set-viewport((-1, -1), (1, 1))

      draw_circ_and_tri(x, y)

      content((x / 2, -.07), anchor: "west", [cos #sym.theta])
      content((x + .35, y / 2), anchor: "east", [sin #sym.theta])
      content((x / 2, y / 2 + .05), anchor: "south", [1])
      content((.20, .05), [#sym.theta])
      circle((x, y), fill: red, radius: 0.02)
      content((x + .16, y + .04), text(16pt)[(cos #sym.theta, \ sin #sym.theta)])
    })
  )
]
)

== Concrete example

Let's make this immediately concrete:

We want a particle effect to circle around the player's character model. Each particle circles at a rate of 1 rotation every 2 seconds.

The initial position of the particle is a vertex attribute. The global time is given in a bind group.

Given a particle, what is its angle of rotation relative to the player it is orbiting?

[let's think about it]

== Answer

1 rotation every 2 seconds means an angular speed of #sym.tau / 2 seconds.

We are given the time, multiply it by the angular speed to solve for angle. So if we're at time 1.5 seconds, then the angle is 1.5/2 = 75% of a turn (75%#sym.tau radians)


#focus-slide("Questions?")

== What about `tan`?

There's one more trigonometric function that we always see that goes with the other two: the tangent.

It's name comes from the fact that it describes the length of a particular tangent line, but in my opinion, that is a less interesting fact about it.

A _more_ interesting (to me) fact about it is that it is the ratio of sine over cosine. Or the vertical component over the horizontal component.

Why would that be interesting?

== The `tan` is the slope of the triangle

Remember rise over run?

That's just sine over cosine.

Knowing the tangent, you immediately know the slope of the triangle, which is a good way of describing the sine and cosine together


== Going backwards 

Let's say we know the rectangular position of something, but we want to know its angle and distance.

Application: we want to give an objective marker to the player. So tell them which way to turn and how many distance units to travel.

We know the player's position and the objectives position, and we've decided that east is in the (1, 0) direction and corresponds to an angle of 0. 

== Going backwards (2)

First, we can create a vector by subtracting two points. #math.equation($B - A$, alt: "B minus A") can be represented as a vector whose tail is at A and whose head touches B. That is, if added to A, the result is B.

This vector in two dimensions has two coordinates, an x and a y.

Those coordinates can be thought of as the legs of a triangle:

#place(bottom + center,
box(height: 25%,
    figure(
      alt: "A line pointing from a point labelled 'A' to a point labelled 'B', The line is named 'V'. A dotted line parallel to the x axis is labelled v-x and a perpendicular line is labelled v-y, both corresponding to the components of V.",
      canvas(length: 4cm, {
        import draw: *;

        line((0, 0), (1.5, 1), mark: (end: (symbol: ">")))
        line((0, 0), (1.5, 0), stroke: (dash: "dashed"))
        line((1.5, 0), (1.5, 1), stroke: (dash: "dashed"))

        content((-.1, 0), [A])
        content((1.6, 1), [B])
        content((.8, -0.1), [Vx])
        content((1.65, 0.5), [Vy])
        content((.7, .65), [V])
      })
    )
  )
)

== Going backwards (3)

To get the distance of a vector (the arrow that points to the destination), we use the pythagorean theorem.

That is, if `Vx` and `Vy` are the legs of a right triangle, and `|V|` is the length of its hypotenuse, then #math.equation($V_x^2 + V_y^2 = |V|^2$, alt: "vee-ex squared plus vee-why squared equals magnitude vee squared"). Or, solving for `|V|`:

#math.equation($|V| = sqrt(V_x^2 + V_y^2)$, alt: "c equals the square root of the quantity a-squared plus b-squared")

So that's how far away the objective is.

But what about its angle?

== Going backwards (4)

#stack(dir: ltr, spacing: 4%,
box(width: 48%)[
We want to solve for #sym.theta

We know the following facts#footnote[These facts come from the fact that when the radius is 1, V-x is just cosine of theta. However, we have to scale by the radius. So if we want to solve for the cosine itself, we have to divide by the radius. Sine and tangent are similar.]:
- #math.equation($cos(theta) = V_x / (|V|)$, alt: "cosine theta equals v-x over magnitude v.")
- #math.equation($sin(theta) = V_y / (|V|)$, alt: "sine theta equals v-y over magnitude v.")
- #math.equation($tan(theta) = V_y / V_x$, alt: "tan theta equals v-y over v-x")

No matter what, we need to use an inverse trig function here...
],
box(width: 48%)[
    #figure(
      alt: "The same right triangle figure from before, but now the inside angle is named 'theta'.",
      canvas(length: 4cm, {
        import draw: *;

        line((0, 0), (1.5, 1), mark: (end: (symbol: "straight")))
        line((0, 0), (1.5, 0), stroke: (dash: "dashed"))
        line((1.5, 0), (1.5, 1), stroke: (dash: "dashed"))

        content((-.1, 0), [A])
        content((1.6, 1), [B])
        content((.8, -0.1), [Vx])
        content((1.65, 0.5), [Vy])
        content((.7, .65), [V])
        content((.27, .08), [#sym.theta])
      })
    )
]
)

== Inverse trig functions

If we want to solve for theta, we need to know the angle that corresponds to one of the side lengths. This is the inverse of the trig functions.

We have several choices:
- #math.equation($theta = arccos(V_x / (|V|))$, alt: "theta equals the arc-cosine of v-x over magnitude V")
- #math.equation($theta = arcsin(V_y / (|V|))$, alt: "theta equals the arc-sine of v-y over magnitude V")
- #math.equation($theta = arctan(V_y / V_x)$, alt: "theta equals the arc-tangent of v-y over v-x")
- #math.equation($theta = "atan2"(V_y, V_x)$, alt: "theta equals the atan2 of v-y and v-x")

Which should we choose

== Using `atan2`

You might not have seen it before, but `atan2` is almost always best.

It's a two argument tangent function. It takes the y and the x.

The reason it exists is that it handles all the little edge cases:
- What if either or both arguments are zero?
- What if either or both arguments are infinity?
- Most important: what if the point is outside the right semicircle

Also, the arccos and arcsin are very sensitive near zero.

So use `Math.atan2` in Javascript/Typescript. 

== Summary so far

So, if we want to use an angle and distance to generate some points (like particules that orbit a player), we use sine, cosine, and multiplication.

If we want to go backwards, we use the pythagorean theorem and `atan2`.

But what do we do if we want to know the angle between two arbitrary vectors? Not the angle from the x axis, but the angle between them? Stay tuned...

#focus-slide("Questions?")

== Arbitrary angles

Let's say we're making a horror game where it's dangerous to look at enemies, or maybe just a spooky enemy that freaks out if you look at it.#footnote[I have the Amnesia games and Endermen from Minecraft in mind here, but feel free to suggest more examples]

We have the position of the enemy and the position of the player like before, but that information is not enough. We also need the direction the camera is pointing.

We could compute the angle between each vector and the x axis using inverse trig functions, and then subtract them.

However, there's an easier way...

== Arbitrary triangles

#stack(dir: ltr, spacing: 4%,
box(width: 48%)[
Imagine the vectors form a triangle like this one.

We can only use the trig functions on right triangles, and this isn't one.

But, there is a useful trigonometric law we can use: *the law of cosines*
],
box(width: 48%)[
#figure(
  alt: "An arbitrary triangle, formed by making vectors A and B form two of the sides, and the third side, C, being the vector A - B. The angle, theta, is unknown.",
  canvas(length: 8cm, {
    import draw: *;
    set-viewport((0, 0), (1, 1))
    line((.1, .1), (.8, .3), mark: (end: (symbol: "straight")))
    line((.1, .1), (1.1, -.4), mark: (end: (symbol: "straight")))
    line((.8, .3), (1.1, -.4), stroke: (dash: "dashed"))
    content((.35, .1), [#sym.theta = ?])
    content((.5, .28), [A])
    content((.6, -.24), [B])
    content((1.0, 0), [C])
  })
)
]
)

== The law of cosines

The law of cosines is useful to solve for the angle of an arbitrary (not-necessarily right) triangle. It states:

#math.equation($|C|^2 = |A|^2 + |B|^2 - 2|A||B| cos(theta)$, alt: "magnitude of c-squared equals magnitude of a-squared plus magnitude of b-squared minus two times magnitude a times magitude b cos theta")

It's a more general case than the pythagorean theorem: the third side length depends on how wide the angle is.  Let's see why this is useful:

#math.equation($|A - B|^2 = |A|^2 + |B|^2 - 2|A||B| cos(theta)$, alt:"magnitude 'a' minus 'b' squared equals magnitude-a squared plus magnitude-b squared minus two times magnitude-a times magnitude-b times cos theta.")

#math.equation($|A - B|^2 = (A_x - B_x)^2 + (A_y - B_y)^2$, alt: "magnitude of quantity A minus B equals the difference in A and B's x components squared, plus the difference in A and B's y components squared.")

#math.equation($ = A_x^2 - 2A_x B_x + B_x^2 + A_y^2 - 2A_y B_y + B_y^2$, alt: "which equals a-x squared minus two times a-x b-x plus b-x squared plus a-y squared minus two times a-y b-y plus b-y squared") 

== The law of cosines (2)

Now let's expand the magnitudes of A and B alone:

#math.equation($|A|^2 = (A_x^2 + A_y^2)$, alt: "Magnitude of A squared equals the sum of a-x squared and a-y squared"), #math.equation($|B|^2 = (B_x^2 + B_y^2)$, alt: "magnitude of B squared equals the sum of b-x squared and b-y squared")

Putting it back together:

#math.equation($A_x^2 - 2A_x B_x + B_x^2 + A_y^2 - 2A_y B_y + B_y^2 = \ A_x^2 + A_y^2 + B_x^2 + B_y^2 - 2|A||B| cos (theta)$, alt: "a-x squared minus two a-x b-x plus b-x squared plus a-y squared minus two a-y b-y plus b-y squared equals a-x squared plus a-y squared plus b-x squared plus b-y squared minus two times the magnitude of a times the magnitude of b times cos theta")

All of the squared magnitudes and the -2 factors cancel. We're left with:

#math.equation($A_x B_x + A_y B_y = |A||B| cos(theta)$, alt: "a-x times b-x plus a-y times b-y equals magnitude a times magnitude b times cos theta.")

== The dot product

If A and B are unit vectors (meaning, length one), we now have a very fast way to calculate a cosine: #math.equation($A dot B = A_x B_x + A_y B_y = cos(theta)$) 
 This calculation is called the *dot product*.


What's so great about this? If the two vectors are the same (and unit length), their dot product will be 1. If they are perpendicular, it will be 0. If they are exactly opposed, it will be -1. 

The cosine between two vectors tells us "how aligned" they are.

The dot-product is therefore one of the most common and useful operations in 3D graphics.

== The norm

The dot-product is typically most useful when one or both vectors is unit-length.

How do we make a vector unit length?

Divide it by its norm, which is the magnitude of the vector. We often write the unit length version of vector #math.equation($v$, alt:"vee") as #math.equation($hat(v)$, alt: "vee hat").

#math.equation($hat(v) = v / (|v|)$)

Converting a vector to a unit-length vector is called *normalization*.

== Solving our question from before

So how do we know if we're looking at the enemy?

Make a vector from our player position to the enemy #math.equation($v = E - P$, alt: "v equals E minus P").

Take the dot product between the unit-length version of that vector and the point that we're looking at (we'll call it 'c', for "camera"). If that value is close enough to 1, we can jump-scare the player:

#math.equation($hat(v) dot hat(c) >= "jump-scare point"$, alt: "v-hat dot c-hat is greater than or equal to 'jump-scare point'")

We don't need the actual angle: the dot product is good enough. The camera vector is usually always unit length, so this is easy to do.

#focus-slide("Questions?")

== Projection

The dot product does something else cool: it calculates the projection of one vector onto another:

#figure(
  alt: "Two vectors, one of which is unit length. There is a dashed vector showing the projection of the longer vector onto the unit length one",
  canvas(length: 7cm, {
    import draw: *;
    set-viewport((0, 0), (1, 1))
    line((0, 0), (.7, .4), mark: (end: (symbol: "straight")))
    line((0, 0), (.4, .1), mark: (end: (symbol: "straight")))
    line((.4, .1), (.79, .2), stroke: (dash: "dashed"), mark: (end: (symbol: "straight")))
  })
)

That is, the longer vector dotted with the unit length vector gives the length of the whole dotted vector (including the part covered up by the unit vector): the shadow.

To project onto non-unit length vectors, normalize:
#math.equation($"proj"(a, b) = a dot b / (|b|)^2$)


== Projection (2)

Why projection?

It's often useful to project a line onto a plane, for example, in an RTS game where you want to draw an arrow showing where a unit is moving.

If you have a normal vector (a vector pointing out perpendicular to a surface), you can check the projection of a vector to a point to the normal vector. Its direction will tell you which side of the surface it is.

Speaking of normal vectors...
