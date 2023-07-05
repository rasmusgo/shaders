#version 330

uniform mat4 matVP;
uniform mat4 matGeo;

uniform vec3 uCamPos;

layout (location = 0) in vec3 pos;

out vec4 rayOrigin;
out vec4 rayDir;

void main() {
   rayOrigin = vec4(pos, 1);
   vec4 posWorld = matGeo * vec4(pos, 1);
   rayDir = vec4(inverse(mat3(matGeo)) * (posWorld.xyz / posWorld.w - uCamPos), 0);
   gl_Position = matVP * matGeo * rayOrigin;
}
