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

#stack(dir: ltr, spacing: 4%,
box(width: 48%)[
  Remember rise over run?

  That's just sine over cosine.

  Knowing the tangent, you immediately know the slope of the triangle, which is a good way of describing the sine and cosine together
],
[
  //#figure(

//  )
]
)