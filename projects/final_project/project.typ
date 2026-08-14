#set document(title: "Final Project")

= Final Project

== The big idea
This is the big one! It's time to show what you've learned. This is an open-ended project where you can build a 3D scene that demonstrates some of the major graphical techniques we've learned how to program.

Then, demonstrate what you did to class and explain how you did it.

== The goal

Come up with a cool scene idea and demonstrate it to the class. There is a checklist of features it must have below: all the basic features are required. Additionally, two advanced features is necessary for undergrads and four for graduate students. There is a checklist of advanced features below which you may pick from, or you can ask me if you have an idea for an advanced feature.

There is only one theme ban: *no solar systems*. Sorry, it's just too frequently the hello world of scene graphs. I'm not going to award credit for solar systems. (If you have an idea that _involves_ a solar system but isn't just a few scene nodes spinning around each other I'm open to it, but you need to get permission first!)

== Teams and AI policy

Normally teamwork is permitted, but assignments are submitted individually. Here, we are going to allow people to present and receive grades as a group. Groups may be no larger than 3 people, and 2 is the recommended number. To join a group, go to the "People" tab in Canvas and add yourself to one of the pre-created groups. You must do this before the deadline (an assignment will be created to remind you).

Joining a group requires the knowledge and consent of everyone in the group. If you add yourself to a group late as a way to try to hop on an already far-along project, you will either be removed from the group (and have to submit independently) or have your grade reduced to match your overall contribution.

== Presentations
Presentations will be per-group, and can either be pre-recorded, in-person, or both. I recommend doing both, since in-person presentations are often more dynamic and memorable, but pre-recorded presentations give a useful backup in case there are technical difficulties.

The specific length of presentations will be given in a canvas announcement, and will depend on class enrollment, number of teams, and project complexity.

During the presentation, make sure to show of all the basic and advanced features you want credit for. These code bases are expected to be on the large side, so if you don't let us know what you did, it might slip through the cracks. I'll have a checklist and do my best to record every feature I see for each project, but please make my job easy!

== Basic features (and grading)

You must have all these features for full credit:
- (10%) At least 4 different meshes visible. These can be procedural or loaded from a file. They must be 3D (a flat plane or triangle alone won't count). They must be correct (e.g, no off-by-one errors in indicies)
- (10%) Texturing. You can use any technique (2D, 3D, cubemaps), but at least two objects must be textured.
- (10%) There must be at least 2 attenuating lights in the scene (i.e., 2 lights that get dimmer as you get farther away from them). There can be more if you want.
- (10%) There must be at least 2 instances of a hierarchical scene-graph relationship. Be sure to call this out and show how the parent object moving causes the child to move.
- (20%) The scene must be interactive, and the camera must move. The simplest way you can achieve this requirement is to have a free-moving camera like in our projects. However, the camera can move along a fixed track, or it can even be a fixed-perspective camera that changes perspective at least once.

Again, be sure to draw attention to these things in your presentation to ensure you get full credit.

== Advanced features (and grading)

Grad students must have _four_ advanced features (10% each). Undergrads only need _two_ (20% each). You will receive *10 bonus points* for every excess advanced feature, so feel free to go wild.

Some of these features have been talked about in class. However, most will require some independent research. Be sure to cite and fully understand any code you get from an external source. If the book has an article on a technique, I put an asterisk by it.

- Advanced texturing\*: mipmaps and multitexturing together (i.e., one object which samples more than one textures and the textures are fully mipmapped).
- Environment maps and skyboxes: both must be present to get this feature.
- Shadow mapping\* or shadow volumes. At least one object casts real-time shadows. Demonstrate that they are real-time by having either the light(s) or object move.
- Transparency\*. Must be correct from any angle (requires sorting or depth peeling).
- Toon shading\*. Requires a visible silhouette, not just color quantization.
- Meaningful compute shaders. You can use them to procedurally generate textures or meshes, or use them for something like collision detection. Don't just write a compute shader, you need to usefully integrate it into your scene.
- Skeletal animation\*. Bones with demonstratable hierarchy that result in a smoothly animated mesh.
- Stencil buffer techniques\*. Good for rendering boats in the water, or portals.
- Texture-based lighting: for example, ambient occlusion, normal mapping, material parameter mapping (i.e., metalness or shininess mapping).
- Physically-based lighting (anything physically-based and more advanced than Phong)
- Pre-baked shadows: environment shadows that are pre-computed as textures.
- Raytracing or radiosity for global illumination. Remember that the project has to be interactive, but you can e.g., use this to precompute a shadow map and get "pre-baked shadows" for free.
- A physics engine (at least with the ability to apply impulses and apply collisions). If you do this using compute shaders it will count for both advanced features.
- A terrain engine (bonus advanced feature for randomly generated terrain, another bonus feature for smoothly streaming terrain)
- Voxel rendering (bonus advanced feature for using marching cubes or a similar algorithm to make smooth voxel meshes).
- Volumetric smoke or fluids with 3D textures.
- A particle system (can't just be points though, must be quads or triangles)
- Geometry-based occlusion culling. You can use an old fashioned visibility matrix for an indoor scene, or a dynamic system based on occlusion queries (or both for double-credit). Frustum culling doesn't count.
- Level-of-detail scaling. I.e., replace complex meshes with simple ones as they get farther away. Bonus points if the last stage is a single billboarded quad.
- Splatting\*

I'm also open to other ideas. Feel free to ask if something you want to do counts as an advanced feature. If you are particularly ambitious, I may count additional advanced features, or count some advanced features multiple times (i.e., more than one useful compute shader, or multiple physically-based lighting techniques), but be sure to ask in advance if your grade depends on it.

To encourage you to try things out that seem difficult but fun, your advanced feature grade is not all or nothing. If you are able to get some of a feature working, I can award partial credit (I will try to match the grade to what I perceive to be the overall feature completion).

== How to submit

Zip up your whole project into an archive that I or a grader can easily build with `npm build` and run in a browser with `npx serve`. Submit that archive.

One submission per team (not per person).

If you pre-record a presentation, please upload it somewhere (your student OneDrive, unlisted Youtube video etc.) and post a link in the relevant announcement. I'll give instructions on where to post it. You must ensure the link remains valid until your final grade is posted.

I may play pre-recorded presentations in class to ensure that people only have to watch one video for completing their peer reviews.

== Absence policy

It may not be possible to have all the presentations on the same day. Code will be due the night before the first day of presentations. You must be ready to present on either day, and the order may be random. I will accept requests to go first, but requests to miss the first day require an excused absence. If a team member isn't able to present, the rest of their team can present on their behalf _if their absence is excused_. 

If you are not picked to go the first day, you are allowed to make last minute changes to the code. This isn't strictly fair but I can't think of a good way to prevent it.

Missing a presentation without an excused absence will result in a zero grade for this project. If you submit a late video to me, the late policy outlined in the syllabus will apply, allowing you to get some points back.

== Peer reviews

You will be reviewing your classmates' projects too. It's important to see what they did to get a better idea of what is possible with the techniques we've learned in class. See the peer review assignment for instructions.

== Alignments
- MO1: basic features grade (60%)
- MO2: meshes are correct (10%)
- MO3: entire assignment (100%)
