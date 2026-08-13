#set document(title: "Project 5: Camera, Scene, and Meshes")

= Project 5

== The big idea

It's time to show you fully understand basic lighting principles. You'll be implementing the Phong shading model in this assignment.

== The goal

You must create a scene with the following objects:
- A floor platform for the other two objects to rest on.
- A sphere of some kind (UV, cube, or geodesic).
- Either another sphere (of any kind) or a teapot.

In addition, the scene must be lit as follows:
- Two spotlights. These will be described in more detail below.
- At least two point lights. These must attenuate visibly (using 1 as all your attenuation factors should work fine for this). In other words: the reflection must be dimmer as the light gets farther away.
- The lights must be moving, and at at least one point in their path, they must illuminate each of the models in the scene. That is, each light must illuminate the floor, the sphere, and the other object at least once in a cycle.

== Spotlights

Spotlights work very similarly to point lights except for a couple of differences:
- You don't have to make them attenuate (you can, but you don't have to in this challenge)
- In addition to a position and a color, spot lights have a *direction* and an *angle*. If the angle between the direction _from_ the light and the spot light's direction is bigger than the spot light's angle, the light is treated as if it didn't exist.


There are two spotlights in my example scene. One blue, shining from above, another green roughly in the same direciton as the camera. Make sure you look at `right.mp4` so you can see them in action.

From this, you know enough trigonometry to define a spotlight. However, there is a #link("https://webgpufundamentals.org/webgpu/lessons/webgpu-lighting-spot.html", "tutorial on spot lights") if you want more info and sample code. Be aware, the author's spot lights are more complex than yours have to be. You don't need a gradual fall-off, you can just have the light cut off abruptly.

== Right

#image("right.png", width: 80%, alt: "a screenshot of the correct scene. See description below.")

=== Description:
- There is a platform floating in space, with a sphere and teapot on it.
- There is a skybox visible.
- Lights are visible shining on the platform, the sphere, and the teapot. We can see two spotlights on the sphere (one green, one blue on its top). Both these spotlights also show up on the platform, faintly.
- There are red, yellow, and cyan point lights visibly reflected on the objects, but most clearly in the teapot. The yellow light is closer to the sphere, the red is in the middle, the cyan is closer to the teapot.

See `right.mp4` to see it in action, with the lights moving.

== Bonus objectives
If you decide to complete a bonus objective, _let us know you did so in the comments_. Otherwise, your hard work may go unrewarded!

+ If you make the object at the center of the scene a pentagonal prism, your grade for this assignment will replace your grade for project 1, if this assignment's grade is higher.
+ If you make the sphere be a cube-sphere and have it be fully textured with *one texture* and having *a different texture for each side*, this assignment's grade will replace your grade for project 2 if it is higher. Have the color you compute in the fragment shader be the texture sample _times_ the final light value.
+ If you add all the same camera controls that you had for project 3 (q and e to rotate, t to look at one of the objects rotating around the cube, r to reset the camera), this assignment's grade will replace your grade for project 3 if it is higher.
+ If you make it so that the two objects in the scene are rotating around each other mutually (as if they were orbiting a hidden object in between them), and you use a hierarchical scene graph in which anything that happens to a parent also happens to its children, this assignment's grade will replace your grade for project 4 if it is higher.

*For 20% bonus score*: give your scene a skybox and make the objects reflective with environment maps. This will require some figuring out, since we didn't go into detail on how to do this. However, the sample uses environment maps, so you have a starting point. (Note: typically we _add_ a portion the reflection from the skybox to the final color. We don't multiply it with the texture like the lights do).

== Hints

- You can hard code the material properties. This can really save a lot of code.
- You can combine all your shaders into one mega shader that shares all the same bind groups. This is useful when, e.g., all 3 models use the same environment map. You can define multiple functions that are `@vertex` and `@fragment`, and in the pipeline, set the entry point for that specific pipeline to the function you want to use as the entry point.
- Remember that lighting is additive. If there are 4 lights, their contributions all add together after accounting for attenuation.
- Debugging lighting code in the shader can be brutal. Remember that you have to understand every line of code, but asking an LLM to help you debug can save tons of time and is not considered cheating. Do not ask the LLM to generate the whole shader for you, or it will almost certainly use a feature that you will not understand, putting your grade at risk.

