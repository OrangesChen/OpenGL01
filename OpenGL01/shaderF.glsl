
uniform sampler2D tex;
varying highp vec2 fragTexCoord;

void main()
{
    // 设置片段着色器中的颜色
     gl_FragColor = texture2D(tex, fragTexCoord);
}
