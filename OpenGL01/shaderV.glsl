// 属性，如果绑定了这个属性
attribute vec4 position;
attribute vec2 vertTexCoord;

//这个值需要和片段着色器的值相同
varying vec2 fragTexCoord;

// const 用于声明非可写的编译时常量变量
// attribute 用于经常更改的信息，只能在顶点着色器中使用
// uniform 用于不经常更改的信息，可用于顶点着色器和片元着色器
// varying 用于修饰从顶点着色器向片元着色器传递的变量

//layout(location = 0) out vec3 fragTexture;

void main()
{
    fragTexCoord = vertTexCoord;
    // 设置顶点位置
    gl_Position = position;
}
