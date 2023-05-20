
//we will be using glsl version 4.5 syntax
#version 460

layout (location = 0) in vec3 vPosition;
layout (location = 1) in vec3 vNormal;
layout (location = 2) in vec4 vColor;
layout (location = 3) in vec2 vTexCoord;

layout (location = 0) out vec4 outColor;
layout (location = 1) out vec2 texCoord;

struct ImageRenderData {
    vec2 imagePosition;
    vec2 imageSize;
    vec2 anchorPoint;
    vec2 scale;
    float alpha;
	vec4 baseColor;
    float zLevel;
};

struct ImageRenderData2{
    ImageRenderData Lmfao;
    float SomeGoodShit;
    vec2 GoodShit;
};

layout(std140, set = 0, binding = 0) readonly buffer ImageBufferObjects {
    ImageRenderData2 objects[];
} objectBuffer;

layout (push_constant) uniform constants 
{
	vec2 extent;
} PushConstants;

void main()
{
	vec2 imagePosition = objectBuffer.objects[gl_BaseInstance].Lmfao.imagePosition;
    vec2 imageSize = objectBuffer.objects[gl_BaseInstance].Lmfao.imageSize;
    vec2 anchor = objectBuffer.objects[gl_BaseInstance].Lmfao.anchorPoint;
    vec2 scale = objectBuffer.objects[gl_BaseInstance].Lmfao.scale;
    float alpha = objectBuffer.objects[gl_BaseInstance].Lmfao.alpha;
	vec4 baseColor = objectBuffer.objects[gl_BaseInstance].Lmfao.baseColor;

	vec2 finalSize = (imageSize / PushConstants.extent);

    vec2 finalPos = ((imagePosition / PushConstants.extent) * 2 - 1) - anchor * finalSize * scale;

	outColor = baseColor;
	//outColor = vec3(vColor.x, vColor.y, vColor.z);
    gl_Position = vec4(
        finalPos.x + ( vPosition.x * finalSize.x ), 
        finalPos.y + (-vPosition.y * finalSize.y ),
        vPosition.z, 1.0
        );
        //1.0); 

	//gl_Position = vec4( ((position.x) - 1.3) * 0.3 * 1.3, (-position.y + 0.05) * 1.3, position.z, 1.0); // + vec4(imagePosition, 0.0f, 1.0f);
    texCoord = vec2(1 - vTexCoord.x, vTexCoord.y);
}

