#version 330

uniform mat4 matVP;
uniform mat4 matGeo;

layout (location = 0) in vec3 pos;

out vec4 rayOrigin;
out vec4 rayDir;

void main() {
   rayOrigin = vec4(pos, 1);
   rayDir = inverse(matVP * matGeo) * vec4(0, 0, 1, 0);
   gl_Position = matVP * matGeo * rayOrigin;
}
