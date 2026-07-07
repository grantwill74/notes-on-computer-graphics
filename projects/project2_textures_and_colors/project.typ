#set document(title: "Project 2: Textures and Colors")

= Project 2

== The big idea

We've learned about colors and textures now. It's time to put our knowledge to work by rendering a bunch of textured, colored, quads. 

The main purpose of this assignment is to really reinforce u/v coordinates and fragment shaders.

Your job is to print the #link("https://en.wikipedia.org/wiki/Konami_Code", "Konami code"), shaded with green. That is: up, up, down, down, left, right, left, right, B, A, and sometimes "start".

This is how it looks if you do the bonus objective (which is drawing "start").

#image("right.png", width: 50%, alt: "a screenshot of the Konami code")

Each symbol is rendered to its own quad. However, I changed the X/Y coordinates to move it to the right, and I changed the U/V coordinates to rotate the arrow or choose a different figure.

The arrows you're going to use, along with B, A, and Start, are all included in a single texture:

#image("symbols.png", width: 20%, alt: "the texture, which contains 4 sub-images in it. The up arrow is the top left image, 'A' is the top right, 'B' is the bottom left, and 'Start' is the bottom right. They are spaced evenly, with no overlap.")

Note this in particular: the U/V coordinates of the _center_ of the texture are 0.5, 0.5. With this knowledge, you can solve for the U/V coordinates of each quad.

You can draw the symbols with any amount of spacing between them, but they must be in the correct order, legible, and not overlapping. 

== Grading
- exactly 10 quads are visible (+ 1 triangle if bonus objective was attempted): 25%
- all the quads are shaded green: 25%
- 

=== Penalties
- Must be gamma correct (-25% if not)

== Bonus objective

The bonus objective is to include "Start". Rules:
+ It must be mapped to a triangle
+ The word "start" must be legible within it
+ No other parts of the texture may bleed over into the word start. It must be the only thing on the triangle. 

To do this, you will have to "grow" the U/V coordinates a little bit. That is, they will have to include parts of the cell containing A and B, but not any pixels of either letter (or objective 3 would be failed).

If you accomplish this objective, the grader will replace your score for project 1 with your score for this project (as a percent), leaving a comment with the previous score and the new one. So if you get a 100% on this project and solve the bonus object, you will get a 100% on project 1.

(I recommend doing it even if you have a 100% on project 1: it's good practice, and the Konami code doesn't feel right without "Start" IMO)

== Hints

- If you are struggling with mapping the U/V or X/Y coordinates, I recommend using paper, and labelling the vertices manually. 
- It's often easier to solve for all the Xs, then all the Ys, then all the Us, then all the Vs, and then interleave them later.
- I really recommend writing a function that will generate the vertices of a quad, given a top-left x/y position, an initial u/v, and which rotation you want.
- How do you shade things? Try averaging the color sampled from the texture with pure green. You can add vectors and even divide them by a scalar.
- Remember to make the texture, pipeline target, and attachment 'srgb'. You'll also need to initialize the canvas context with an 'srgb' view. That last one is done in sample01, and sample04 shows how to set up a gamma correct pipeline. If you don't do a gamma correct pipeline, your green shading will be too dark.

== Alignments
- MO1: entire grade
- MO2: entire grade
- MO3: entire grade

