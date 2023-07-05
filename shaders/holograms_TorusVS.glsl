#version 330

uniform mat4 matVP;
uniform mat4 matGeo;

layout (location = 0) in vec3 pos;

out vec4 rayOrigin;
out vec4 rayDir;

void main() {
   gl_Position = matVP * matGeo * vec4(pos, 1);
}
