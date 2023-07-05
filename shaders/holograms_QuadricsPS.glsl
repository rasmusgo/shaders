#version 330

uniform mat4 matVP;
uniform mat4 matGeo;

uniform int uSurfaceID;
uniform int uBoundsID;
uniform vec3 uAlbedoColor = vec3(0.5, 0.5, 0.5);
uniform float uSpecularity = 0.5;
uniform float uSpecularExponent = 100;

in vec4 rayOrigin;
in vec4 rayDir;

out vec4 outColor;

// Surfaces are at pᵀQp = 0
// Bounds restrict the surface to pᵀQp <= 0
const mat4 quadrics[4] = mat4[](
    mat4( // Sphere with radius 0.5
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, -0.25),
    mat4( // Shifted sphere
    -1.0, 0.0, 0.0, 0.0,
    0.0, -1.0, 0.0, -0.2,
    0.0, 0.0, -1.0, 0.0,
    0.0, -0.2, 0.0, 0.15),
    mat4( // Straight cylinder
    1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, -(0.5*0.5)),
    mat4( // Double planes, facing outwards
    0.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, -0.25)
);

const vec3 lightDir1 = normalize(vec3(1.0, 1.0, 1.0));
const vec3 lightDir2 = normalize(vec3(-1.0, 1.0, 1.0));
const vec3 lightColor1 = vec3(1.0, 1.0, 0.5);
const vec3 lightColor2 = vec3(1.0, 0.5, 0.5);
const vec3 ambientColor = vec3(0.1, 0.15, 0.25);

void main()
{
    // Select quadric parameters for surface and bounds.
    mat4 surfaceQ = quadrics[uSurfaceID];
    mat4 boundsQ = quadrics[uBoundsID];

    // Find ray-quadric intersection, if any
    float a = dot(rayDir, surfaceQ * rayDir);
    float b = dot(rayOrigin, surfaceQ * rayDir);
    float c = dot(rayOrigin, surfaceQ * rayOrigin);
    // Discriminant from quadratic formula
    // b^2 - 4ac
    // but we are able to simplify it by substituting b with b/2.
    float discriminant = b * b - a * c;
    if (discriminant < 0.0) {
	    discard;
    }

    // Pick the solution that is facing us
    float t = -(b + sqrt(discriminant)) / a;

    // Discard stuff behind us
    if (t < -0.0) {
	    discard;
    }

    // Find the hit point in world space
    vec4 hitPoint = rayOrigin + rayDir * t;
    float boundsValue = dot(hitPoint, boundsQ * hitPoint);

    // Discard fragments that are out of bounds
    if (boundsValue > 0.0) {
	    discard;
    }

    // Compute depth
    vec4 v_clip_coord = matVP * matGeo * hitPoint;
    float f_ndc_depth = v_clip_coord.z / v_clip_coord.w;
    gl_FragDepth = f_ndc_depth;

    // Compute normal from gradient of surface quadric
    vec3 normal = normalize((surfaceQ * hitPoint).xyz);
    vec3 reflectionDIr = normalize(reflect(rayDir.xyz, normal));

    // Use the normal for coloring
    outColor = vec4(uAlbedoColor * (
        lightColor1 * max(0.0, dot(normal, lightDir1)) +
        lightColor2 * max(0.0, dot(normal, lightDir2)) +
        ambientColor) +
        uSpecularity * (
        lightColor1 * pow(max(0.0, dot(reflectionDIr, lightDir1)), uSpecularExponent) +
        lightColor2 * pow(max(0.0, dot(reflectionDIr, lightDir2)), uSpecularExponent) +
        ambientColor), 1.0);
}
