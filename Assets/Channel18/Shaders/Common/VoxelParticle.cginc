#ifndef __VPARTICLE_COMMON_INCLUDED__
#define __VPARTICLE_COMMON_INCLUDED__

struct VParticle {
	float3 position;
    float4 rotation;
    float3 scale;
    float3 velocity;
	float4 color;
    float speed;
    float lifetime;
    bool flow;
};

#endif
