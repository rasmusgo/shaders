#version 330

uniform mat4 matVP;
uniform mat4 matGeo;

uniform int uBoundsID = 0;
uniform vec3 uAlbedoColor = vec3(0.5, 0.5, 0.5);
uniform float uSpecularity = 0.5;
uniform float uSpecularExponent = 100;

in vec4 rayOrigin;
in vec4 cameraPos;

out vec4 outColor;

// Surfaces are at pᵀQp = 0
// Bounds restrict the surface to pᵀQp <= 0
const mat4 quadrics[1] = mat4[](
    mat4( // Plane at y = 0
    0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, -1.0,
    0.0, 0.0, 0.0, 0.0,
    0.0, -1.0, 0.0, 0.0)
);

// From https://iquilezles.org/articles/intersectors/
// f(x) = (|x|² + R² - r²)² - 4·R²·|xy|² = 0
float torusIntersect( in vec3 ro, in vec3 rd, in vec2 tor )
{
    float po = 1.0;

    float Ra2 = tor.x*tor.x;
    float ra2 = tor.y*tor.y;

    float m = dot(ro,ro);
    float n = dot(ro,rd);

    // bounding sphere
    {
	float h = n*n - m + (tor.x+tor.y)*(tor.x+tor.y);
	if( h<0.0 ) return -1.0;
	//float t = -n-sqrt(h); // could use this to compute intersections from ro+t*rd
    }

	// find quartic equation
    float k = (m - ra2 - Ra2)/2.0;
    float k3 = n;
    float k2 = n*n + Ra2*rd.z*rd.z + k;
    float k1 = k*n + Ra2*ro.z*rd.z;
    float k0 = k*k + Ra2*ro.z*ro.z - Ra2*ra2;

    #if 1
    // prevent |c1| from being too close to zero
    if( abs(k3*(k3*k3 - k2) + k1) < 0.01 )
    {
        po = -1.0;
        float tmp=k1; k1=k3; k3=tmp;
        k0 = 1.0/k0;
        k1 = k1*k0;
        k2 = k2*k0;
        k3 = k3*k0;
    }
	#endif

    float c2 = 2.0*k2 - 3.0*k3*k3;
    float c1 = k3*(k3*k3 - k2) + k1;
    float c0 = k3*(k3*(-3.0*k3*k3 + 4.0*k2) - 8.0*k1) + 4.0*k0;


    c2 /= 3.0;
    c1 *= 2.0;
    c0 /= 3.0;

    float Q = c2*c2 + c0;
    float R = 3.0*c0*c2 - c2*c2*c2 - c1*c1;


    float h = R*R - Q*Q*Q;
    float z = 0.0;
    if( h < 0.0 )
    {
    	// 4 intersections
        float sQ = sqrt(Q);
        z = 2.0*sQ*cos( acos(R/(sQ*Q)) / 3.0 );
    }
    else
    {
        // 2 intersections
        float sQ = pow( sqrt(h) + abs(R), 1.0/3.0 );
        z = sign(R)*abs( sQ + Q/sQ );
    }
    z = c2 - z;

    float d1 = z   - 3.0*c2;
    float d2 = z*z - 3.0*c0;
    if( abs(d1) < 1.0e-4 )
    {
        if( d2 < 0.0 ) return -1.0;
        d2 = sqrt(d2);
    }
    else
    {
        if( d1 < 0.0 ) return -1.0;
        d1 = sqrt( d1/2.0 );
        d2 = c1/d1;
    }

    //----------------------------------

    float result = 1e20;

    h = d1*d1 - z + d2;
    if( h > 0.0 )
    {
        h = sqrt(h);
        float t1 = -d1 - h - k3; t1 = (po<0.0)?2.0/t1:t1;
        float t2 = -d1 + h - k3; t2 = (po<0.0)?2.0/t2:t2;
        if( t1 > 0.0 ) result=t1;
        if( t2 > 0.0 ) result=min(result,t2);
    }

    h = d1*d1 - z - d2;
    if( h > 0.0 )
    {
        h = sqrt(h);
        float t1 = d1 - h - k3;  t1 = (po<0.0)?2.0/t1:t1;
        float t2 = d1 + h - k3;  t2 = (po<0.0)?2.0/t2:t2;
        if( t1 > 0.0 ) result=min(result,t1);
        if( t2 > 0.0 ) result=min(result,t2);
    }

    return result;
}

// From https://iquilezles.org/articles/intersectors/
vec3 torusNormal( in vec3 pos, vec2 tor )
{
    return normalize( pos*(dot(pos,pos)-tor.y*tor.y - tor.x*tor.x*vec3(1.0,1.0,-1.0)));
}

const vec3 lightDir1 = normalize(vec3(1.0, 1.0, 1.0));
const vec3 lightDir2 = normalize(vec3(-1.0, 1.0, 1.0));
const vec3 lightColor1 = vec3(1.0, 1.0, 0.5);
const vec3 lightColor2 = vec3(1.0, 0.5, 0.5);
const vec3 ambientColor = vec3(0.1, 0.15, 0.25);

void main()
{
    vec2 torus = vec2(0.25, 0.05);

    // Find ray-torus intersection, if any
    vec3 ro = rayOrigin.xyz / rayOrigin.w;
    vec3 cp = cameraPos.xyz / cameraPos.w;
    vec3 rd = normalize(ro - cp);
    float t = torusIntersect(ro, rd, torus);

    // Discard stuff behind us
    if (t < -0.0) {
        discard;
    }

    // Find the hit point in local space
    vec4 hitPoint = vec4(ro + rd * t, 1.0);

    // Use quadric bounds.
    mat4 boundsQ = quadrics[uBoundsID];
    float boundsValue = dot(hitPoint, boundsQ * hitPoint);

    // Discard fragments that are out of bounds
    if (boundsValue > 0.0) {
	    discard;
    }

    // Compute depth
    vec4 v_clip_coord = matVP * matGeo * hitPoint;
    float f_ndc_depth = v_clip_coord.z / v_clip_coord.w;
    gl_FragDepth = f_ndc_depth;

    // Compute normal
    vec3 normal = torusNormal(hitPoint.xyz, torus);
    vec3 reflectionDIr = normalize(reflect(rd, normal));

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
