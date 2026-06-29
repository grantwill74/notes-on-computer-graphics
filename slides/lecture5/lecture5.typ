== Not so fast


Instead, we want to store the vertices in an array in GPU memory, called a buffer. Then we want the vertex shader to read out of that.

This requires us to modify our sample as follows:
- Change the shader to receive data from a buffer
- Create a buffer which stores the triangle data
- Tell the pipeline to get its data from a buffer
- Bind that buffer with a command so that it's there when needed.

== Changing the shader

