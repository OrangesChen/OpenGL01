// 属性，如果绑定了这个属性
attribute vec4 position;
attribute vec2 vertTexCoord;

//这个值需要和片段着色器的值相同
varying vec2 fragTexCoord;


//layout(location = 0) out vec3 fragTexture;

void main()
{
    fragTexCoord = vertTexCoord;
    // 设置顶点位置
    gl_Position = position;
}
