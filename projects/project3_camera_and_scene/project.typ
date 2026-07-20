#set document(title: "Project 3: Camera and Scene")

= Project 3

== The big idea

We've made some WebGPU applications, but none of them have been truly interactive or 3D. Time to change that! With this project, we are going to build a 3D flying camera, like the one in `sample09`, but with some extra features. We're also going to make a 3D scene.

=== The scene
In this assignment, you will make a scene full of cubes. You must have at least 4 cubes, and they can be positioned however you want, as long as they are all within viewing distance of each other and can all be interpreted as separate objects (don't put one cube inside another).
- The first cube must be a perfect cube (same dimensions in each axis).
- The second cube must have the same width and depth, but must be scaled to have double y length (height).
- The third cube must have the same depth and height, but must have double x length.
- The forth cube must have all 3 dimensions twice as large as the first cube, making it have 8 times the volume.
- All the cubes must be animated in some way. That is, they can be rotating (around any axis), stretching, bouncing, whatever you want. Remember that the sample contains some examples of animation.
- All the cubes must have each face with a different color (or texture).

=== The camera
You must implement the same flying camera that was demonstrated in `sample09`, with some additional features:
+ When the 'R' button is pressed, the camera must reset to the origin. It must be looking in the (0, 0, 1) (Z+) direction, and it must be situated at the origin. At least one cube must be visible from this orientation and position.
+ When the 'T' button is pressed, the camera must look at the largest cube. That is, it must snap to rotate such that it is pointing at that cube. It can have any amount of roll. You can use the `lookAt` function if you wish, but be aware that that function generates a `view` matrix, not a `model` matrix. Alternatively, you can use trigonometry to solve for X and Z rotation needed to look at the object.
+ When the Q button is pressed, the camera must roll counter-clockwise. When the E button is pressed, the camera must roll clockwise. Note that rolling must happen _first_ in the order of transformations. If I roll and then pitch up, I should pitch up relative to the roll direction.
+ All the other camera controls (WASD for forward, left, back, right; C for down, Space for up, arrows for rotation) should remain the same. You can choose to invert the pitch axis if you want.

== Bonus objectives

- Define and draw an additional shape which is a pentagonal prism. This will accompany the cubes, and can be located however you want. It must have every side a different color. It does not have to be animated. If you do this, your project 1 score will be replaced with your score for this assignment.
- Make at least one of the cubes textured. Use a _single texture_ that contains all 6 sides of the cube, and apply them to each side of the cube. If you do this, your grade for this assignment will replace your grade for project 2.

== Right
See the attached "right.mp4" to see the camera in action. Here's a description of what it's doing:
- The camera starts by moving backwards
- Then, I hit T, casing the view to snap to the 4th box (which is below the horizon)
- I move to the left, holding T, which causes me to stay locked on to the object.
- After moving about a quarter turn I hit R to reset the camera.
- Now I roll right, then left, then right again. I look up and down while rolled to show how I still look up and down relative to the fixed global axis while maintaining my roll. Yours should behave the same way. Remember TYPRS! 


== Grading

- (20%) cubes have correct dimensions and colors
- (20%) cubes are animated 
- (20%) R button works
- (20%) T button works
- (20%) Rolling with Q and E works.

Up to a -25% penalty applies if the other camera controls are not working correctly.
Up to a -25% penalty applies if the cube meshes are incorrect (i.e., visible seams, not a box shape, or mixed colors)

== Hints 

- If you use a scale matrix, you can reuse the same cube mesh all 4 times, and only change the scale. This is a reward for thinking in matrices!
- What does the identity matrix mean when interpreted as a camera matrix?
- `mat4.targetTo` is the easiest way to look at an object initially. It returns a new model matrix you can use. But how can you get the pitch, yaw, and roll back out? It might be easier to use some trig and compute the yaw and pitch yourself. The pitch can be computed with just the arcsine. The yaw is easiest with `atan2`.
- I didn't specify the "up" direction for the targetting requirement. It's fine to use whatever.

== Submission

Please submit the same way the previous two projects were submitted. Submit the code in the text window for archival purposes. Then, attach a zip to a comment. Remember to have an `html` file named `index.html`, and to have everything be buildable by the TA running `npm update`, `npx tsc` in your root directory.

Make sure you installed your matrix library correctly! Look at the source map in your HTML file, and ensure that the paths you provide will take the browser from the current file to the matrix library. Ensure that the paths in your `tsconfig.json` file are also correct, so that there will not be errors when compiling.

== Alignments
- MO1: entire grade
- MO2: cube mesh and dimensionality correct
- MO3: entire grade