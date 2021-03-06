
#include "UnityCG.cginc"
#include "UnityGBuffer.cginc"
#include "UnityStandardUtils.cginc"

// Cube map shadow caster; Used to render point light shadows on platforms
// that lacks depth cube map support.
#if defined(SHADOWS_CUBE) && !defined(SHADOWS_CUBE_IN_DEPTH_TEX)
#define PASS_CUBE_SHADOWCASTER
#endif

half4 _Color, _Emission;
sampler2D _MainTex;
float4 _MainTex_ST;

half _Glossiness;
half _Metallic;

float _Size;

#include "../Common/Random.cginc"
#include "../Common/Quaternion.cginc"
#include "../Common/VoxelParticle.cginc"

StructuredBuffer<VParticle> _ParticleBuffer;

// Vertex input attributes
struct Attributes
{
    float4 position : POSITION;
    float4 rotation : TANGENT;
    float3 size : NORMAL;
	float3 color : COLOR;
};

// Fragment varyings
struct Varyings
{
    float4 position : SV_POSITION;

#if defined(PASS_CUBE_SHADOWCASTER)
    // Cube map shadow caster pass
    float3 shadow : TEXCOORD0;

#elif defined(UNITY_PASS_SHADOWCASTER)
    // Default shadow caster pass

#else
    // GBuffer construction pass
    float3 normal : NORMAL;
    half3 ambient : TEXCOORD0;
    float3 wpos : TEXCOORD1;
	float3 color : COLOR;
#endif
};

//
// Vertex stage
//

Attributes Vertex(Attributes input, uint vid : SV_VertexID)
{
    VParticle particle = _ParticleBuffer[vid];
    input.position = float4(particle.position, 1);
    input.size = particle.scale;
    input.rotation = particle.rotation;
	input.color.rgb = particle.color.rgb;
    return input;
}

//
// Geometry stage
//

Varyings VertexOutput(in Attributes IN, in Varyings o, float4 pos, float3 wnrm)
{
    float3 wpos = mul(unity_ObjectToWorld, pos).xyz;

#if defined(PASS_CUBE_SHADOWCASTER)
    // Cube map shadow caster pass: Transfer the shadow vector.
    o.position = UnityObjectToClipPos(float4(wpos.xyz, 1));
    o.shadow = wpos.xyz - _LightPositionRange.xyz;

#elif defined(UNITY_PASS_SHADOWCASTER)
    // Default shadow caster pass: Apply the shadow bias.
    float scos = dot(wnrm, normalize(UnityWorldSpaceLightDir(wpos.xyz)));
    wpos.xyz -= wnrm * unity_LightShadowBias.z * sqrt(1 - scos * scos);
    o.position = UnityApplyLinearShadowBias(UnityWorldToClipPos(float4(wpos.xyz, 1)));

#else
    // GBuffer construction pass
    o.position = UnityWorldToClipPos(float4(wpos.xyz, 1));
    o.normal = wnrm;
    o.ambient = ShadeSHPerVertex(wnrm, 0);
    o.wpos = wpos.xyz;
	o.color = IN.color;
#endif

    return o;
}

void addFace (in Attributes IN, inout TriangleStream<Varyings> OUT, float4 p[4], float3 normal)
{
    float3 wnrm = UnityObjectToWorldNormal(normal);
    Varyings o;
	UNITY_INITIALIZE_OUTPUT(Varyings, o);
    o = VertexOutput(IN, o, p[0], wnrm);
    OUT.Append(o);

    o = VertexOutput(IN, o, p[1], wnrm);
    OUT.Append(o);

    o = VertexOutput(IN, o, p[2], wnrm);
    OUT.Append(o);

    o = VertexOutput(IN, o, p[3], wnrm);
    OUT.Append(o);

    OUT.RestartStrip();
}

[maxvertexcount(24)]
void Geometry (point Attributes IN[1], inout TriangleStream<Varyings> OUT) {

    float3 halfS = 0.5f * IN[0].size;

    float3 pos = IN[0].position.xyz;
    float3 right = rotate_vector(float3(1, 0, 0), IN[0].rotation) * halfS.x;
    float3 up = rotate_vector(float3(0, 1, 0), IN[0].rotation) * halfS.y;
    float3 forward = rotate_vector(float3(0, 0, 1), IN[0].rotation) * halfS.z;

    float4 v[4];

	// forward
    v[0] = float4(pos + forward + right - up, 1.0f);
    v[1] = float4(pos + forward + right + up, 1.0f);
    v[2] = float4(pos + forward - right - up, 1.0f);
    v[3] = float4(pos + forward - right + up, 1.0f);
    addFace(IN[0], OUT, v, normalize(forward));

	// back
    v[0] = float4(pos - forward - right - up, 1.0f);
    v[1] = float4(pos - forward - right + up, 1.0f);
    v[2] = float4(pos - forward + right - up, 1.0f);
    v[3] = float4(pos - forward + right + up, 1.0f);
    addFace(IN[0], OUT, v, -normalize(forward));

	// up
    v[0] = float4(pos - forward + right + up, 1.0f);
    v[1] = float4(pos - forward - right + up, 1.0f);
    v[2] = float4(pos + forward + right + up, 1.0f);
    v[3] = float4(pos + forward - right + up, 1.0f);
    addFace(IN[0], OUT, v, normalize(up));

	// down
    v[0] = float4(pos + forward + right - up, 1.0f);
    v[1] = float4(pos + forward - right - up, 1.0f);
    v[2] = float4(pos - forward + right - up, 1.0f);
    v[3] = float4(pos - forward - right - up, 1.0f);
    addFace(IN[0], OUT, v, -normalize(up));

	// left
    v[0] = float4(pos + forward - right - up, 1.0f);
    v[1] = float4(pos + forward - right + up, 1.0f);
    v[2] = float4(pos - forward - right - up, 1.0f);
    v[3] = float4(pos - forward - right + up, 1.0f);
    addFace(IN[0], OUT, v, -normalize(right));

	// right
    v[0] = float4(pos - forward + right + up, 1.0f);
    v[1] = float4(pos + forward + right + up, 1.0f);
    v[2] = float4(pos - forward + right - up, 1.0f);
    v[3] = float4(pos + forward + right - up, 1.0f);
    addFace(IN[0], OUT, v, normalize(right));
};

//
// Fragment phase
//

#if defined(PASS_CUBE_SHADOWCASTER)

// Cube map shadow caster pass
half4 Fragment(Varyings input) : SV_Target
{
    float depth = length(input.shadow) + unity_LightShadowBias.x;
    return UnityEncodeCubeShadowDepth(depth * _LightPositionRange.w);
}

#elif defined(UNITY_PASS_SHADOWCASTER)

// Default shadow caster pass
half4 Fragment() : SV_Target { return 0; }

#else

// GBuffer construction pass
void Fragment (Varyings input, out half4 outGBuffer0 : SV_Target0, out half4 outGBuffer1 : SV_Target1, out half4 outGBuffer2 : SV_Target2, out half4 outEmission : SV_Target3) {
    // Sample textures
    // half3 albedo = input.color.rgb * _Color.rgb;
    half3 albedo = _Color.rgb;

    // PBS workflow conversion (metallic -> specular)
    half3 c_diff, c_spec;
    half refl10;
    c_diff = DiffuseAndSpecularFromMetallic(
        albedo, _Metallic, // input
        c_spec, refl10 // output
    );

    // Update the GBuffer.
    UnityStandardData data;
    data.diffuseColor = c_diff;
    data.occlusion = 1.0;
    data.specularColor = c_spec;
    data.smoothness = _Glossiness;
    data.normalWorld = input.normal;
    UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

    // Calculate ambient lighting and output to the emission buffer.
    half3 sh = ShadeSHPerPixel(data.normalWorld, input.ambient, input.wpos);
    outEmission = (float4(input.color.rgb, 1) * _Emission) + half4(sh * c_diff, 1);
    // outEmission = _Emission;
}

#endif
