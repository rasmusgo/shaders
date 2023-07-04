#version 330

uniform mat4 matVP;
uniform mat4 matGeo;

layout (location = 0) in vec3 pos;

out vec4 rayOrigin;
out vec4 cameraPos;

void main() {
   rayOrigin = vec4(pos, 1);
   cameraPos = inverse(matVP * matGeo) * vec4(0, 0, 0, 1);
   cameraPos = cameraPos / cameraPos.w;
   gl_Position = matVP * matGeo * rayOrigin;
}
