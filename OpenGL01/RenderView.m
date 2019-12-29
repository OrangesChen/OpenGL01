//
//  CubeView.m
//  CubeRotation
//
//  Created by cfq on 16/9/18.
//  Copyright © 2016年 cfq. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RenderView.h"
#import <OpenGLES/ES3/gl.h>

@interface RenderView()
//EAGLContext管理所有通过OpenGL进行draw的信息
@property (nonatomic, strong) EAGLContext *mContext;
//CALayer的子类，用来显示任意的OpenGL图形
@property (nonatomic, strong) CAEAGLLayer *glLayer;
//Program: -一个OpenGL ES对象，包含了你想要用来绘制一个或多个形状的shader。
@property (nonatomic, assign) GLuint renderProgram;
@property (nonatomic, assign) GLuint squareVertices;

@property (nonatomic, assign) GLuint colorRenderBuffer;
@property (nonatomic, assign) GLuint colorFrameBuffer;

- (void) setupLayer;

@end

// Texture
typedef struct {
    GLuint id;
    GLsizei width, height;
} textureInfo_t;


@implementation RenderView

// default is [CALayer class]. Used when creating the underlying layer for the view.
//重写layerClass方法，使用CAEAGLLayer来显示
+ (Class)layerClass {
    //CAEAGLLayer: CALayer的子类，用来显示任意的OpenGL图形,是苹果专门为ES准备的一个图层类，它用于保存渲染缓冲区
    return [CAEAGLLayer class];
}

- (void)layoutSubviews {
//    [self addRotation];
    [self setupLayer];
    [self setupContext];
//    [self destoryRenderAndFrameBuffer];
    [self setupRenderBuffer];
    
    [self setupFrameBuffer];
    [self drawPrepare];
    [self render];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        while (1) {
            [self render];
        }
    });
    
}

// 设置layer为不透明状态,因为缺省的话，CALayer是透明的。而透明层对性能的负荷很大，特别是OpengGL的层。
- (void) setupLayer {
    
    self.glLayer = (CAEAGLLayer *)self.layer;
    //设置放大倍数
    //在iphone的retina屏幕上面，必须要设置，contentScaleFactor属性。这个属性的默认值是1。对应的retina屏幕需要是2.可以通过下面的方式来设置：
    [self setContentScaleFactor:[[UIScreen mainScreen] scale]];
    
    // CALayer 默认是透明的，必须将它设为不透明才能让其可见
    self.glLayer.opaque = YES;
    
    // 设置描绘属性，在这里设置不维持渲染内容以及颜色格式为 RGBA8
    /**
     *  为了保存层中用到的OpenGL ES的帧缓存类型的信息 这段代码是告诉Core Animation要试图保留任何以前绘制的图像留作以后重用
     */
    // 双缓存机制：单缓存机制是在渲染前必须要清空画面然后再进行渲染，这样在重绘的过程中会不断的闪烁。双缓存机制，是在后台先将需要绘制的画面绘制好然后再显示绘制出来
    self.glLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
}

//EAGLContext管理所有通过OpenGL进行draw的信息，创建一个context并声明用的哪个版本
- (void)setupContext {
    // 指定 OpenGL 渲染 API 的版本，在这里我们使用 OpenGL ES 3.0
    EAGLRenderingAPI api = kEAGLRenderingAPIOpenGLES3;
    EAGLContext* context = [[EAGLContext alloc] initWithAPI:api];
    if (!context) {
        NSLog(@"Failed to initialize OpenGLES 3.0 context");
        exit(1);
    }
    
    // 设置为当前上下文
    if (![EAGLContext setCurrentContext:context]) {
        NSLog(@"Failed to set current OpenGL context");
        exit(1);
    }
    self.mContext = context;
}

//删除缓冲
- (void)destoryRenderAndFrameBuffer
{
    /**
     *  删除帧缓冲对象
     */
    glDeleteFramebuffers(1, &_colorFrameBuffer);
    self.colorFrameBuffer = 0;
    /**
     *  删除渲染缓冲
     */
    glDeleteRenderbuffers(1, &_colorRenderBuffer);
    self.colorRenderBuffer = 0;
}

- (void)drawPrepare {
    //获取视图放大倍数
    CGFloat scale = [[UIScreen mainScreen] scale];
    glViewport(0, self.frame.size.width, self.frame.size.width *scale, self.frame.size.width *scale);
    //获取渲染顶点和片段文件路径
    NSString *vertFile = [[NSBundle mainBundle] pathForResource:@"shaderV" ofType:@"glsl"];
    NSString *fragFile = [[NSBundle mainBundle] pathForResource:@"shaderF" ofType:@"glsl"];
    if (self.renderProgram) {
        glDeleteProgram(self.renderProgram);
        self.renderProgram = 0;
    }
    
    self.renderProgram = [self loadShaders:vertFile frag:fragFile];
    
    //链接程序
    [self linkProgram:self.renderProgram];
    
    //创建索引, 申请内存标志
    glGenBuffers(1, &_squareVertices);
    
    //顶点数据，前三个是顶点坐标，后面两个是纹理坐标
    GLfloat squareVertexData[] =
    {
        0.5, -0.5, 0.0f,    1.0f, 0.0f, //右下
        -0.5, 0.5, 0.0f,    0.0f, 1.0f, //左上
        -0.5, -0.5, 0.0f,   0.0f, 0.0f, //左下
        0.5, 0.5, -0.0f,    1.0f, 1.0f, //右上
    };
    
    //        GLfloat squareVertexData[] =
    //           {
    //               0.5, -0.5, 0.0f,    0.0f, 1.0f, //右下
    //               -0.5, 0.5, 0.0f,    1.0f, 0.0f, //左上
    //               -0.5, -0.5, 0.0f,   1.0f, 1.0f, //左下
    //               0.5, 0.5, -0.0f,    0.0f, 0.0f, //右上
    //           };
    
    //在glBufferData之前需要将要使用的缓冲区绑定
    glBindBuffer(GL_ARRAY_BUFFER, _squareVertices);
    /**
     *  把数据传到缓冲区，申请内存空间
     *
     *  @param target 与绑定缓冲区时使用的目标相同
     *  @param size   我们将要上传的数据大小，以字节为单位
     *  @param data   将要上传的数据本身
     *  @param usage  告诉OpenGL我们打算如何使用缓冲区
     */
    glBufferData(GL_ARRAY_BUFFER, sizeof(squareVertexData), squareVertexData, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, _squareVertices);
    
    GLuint position = glGetAttribLocation(self.renderProgram, "position");
    /**
     *  设置指针，为vertex shader的两个输入参数配置两个合适的值。
     *
     *  @param _positionSlot 声明这个属性的名称
     *  @param 3             定义这个属性由多少个值组成，顶点是3个，颜色是4个
     *  @param GL_FLOAT      声明每一个值是什么类型
     *  @param GL_FALSE
     *  @param Vertex        描述每个vertex数据大小的方式，所以可以简单的传入
     *                       sizeof(Vertex)
     *  最后一个是数据结构的偏移量
     *  @return
     */
    glVertexAttribPointer(position, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, NULL);
    // 开启顶点数据
    glEnableVertexAttribArray(position);
    
    // 获取纹理属性
    GLuint vertTexCoord = glGetAttribLocation(self.renderProgram, "vertTexCoord");
    glVertexAttribPointer(vertTexCoord, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, (GLfloat *)NULL + 3);
    glEnableVertexAttribArray(vertTexCoord);
    glActiveTexture(GL_TEXTURE0);
    
    //顶点索引
    GLuint indices[] =
    {
        0, 1, 2,
        1, 3, 0
    };
    GLuint index;
    glGenBuffers(1, &index);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, index);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    
    //设置纹理贴图
    [self textureFromName:@"mandrill"];
    
}

// 渲染
- (void)render {
    //glClearColor: 设置要清空缓冲的颜色。当调用glClear函数之后，整个指定清空的缓冲区都被填充为glClearColor所设置的颜色。
    glClearColor(1.0, 0.0, 1.0, 1.0);
    //清空屏幕缓冲区的颜色
    glClear(GL_COLOR_BUFFER_BIT);
    
   
    //设置视口大小
//    glViewport(self.frame.origin.x*scale, self.frame.origin.y*scale, self.frame.size.width *scale, self.frame.size.height * scale);
    
   
//    glBindVertexArray(0);

    /**
     *  在每个vertex上调用我们的vertex shader,以及每个像素调用fragment shader，最终画出我们的矩形
     */
    /**
     *  绘制函数
     *
     *  @param mode  绘制方式
     *  @param count 顶点索引个数
     *  @param type  索引数据类型
     *  @param indices 顶点索引数组地址
     *
     *  @return
     */
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    //绘制到渲染缓冲区
    [self.mContext presentRenderbuffer:GL_RENDERBUFFER];
}


- (BOOL)linkProgram:(GLint)pro {
    //链接程序
    glLinkProgram(self.renderProgram);
    GLint linkSuccess;
    glGetProgramiv(self.renderProgram, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar message[256];
        glGetProgramInfoLog(self.renderProgram, sizeof(message), 0, &message[0]);
        NSString *messageString = [NSString stringWithUTF8String:message];
        NSLog(@"error: %@", messageString);
        return NO;
    } else {
        //加载并使用链接好的程序。
        glUseProgram(self.renderProgram);
        return YES;
    }
}

//编译shader
- (void)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file {
    //获取文件内容，格式转化为UTF8
    NSString* content = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
    
    //创建一个代表shader的OpenGL对象。这时你必须告诉OpenGL,你想创建的是frament shader 还是 vertex shader.所以便有了这个参数：type
    // 根据类型创建着色器
    *shader = glCreateShader(type);
    
    //让OpenGL获取到这个shader的源代码，把NSString转换成C-string
    const GLchar* source = (GLchar *)[content UTF8String];
    // 获取着色器的数据源
    glShaderSource(*shader, 1, &source, NULL);
    
    //运行时编译shader
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    // 查看是否编译成功
    GLint status;
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        NSLog(@"Compile fail");
    }
    
    NSLog(@"Compile success");
}

//加载shader
- (GLuint)loadShaders:(NSString *)vert frag:(NSString *)frag {
    GLuint verShader, fragShader;
    //创建一个空的OpenGL ES Program
    GLint program = glCreateProgram();
    
    [self compileShader:&verShader type:GL_VERTEX_SHADER file:vert];
    [self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:frag];
    // 将vertex shader添加到program
    glAttachShader(program, verShader);
    // 将fragment shader添加到program
    glAttachShader(program, fragShader);
    
    // Free up no longer needed shader resources
    glDeleteShader(verShader);
    glDeleteShader(fragShader);
    
    return program;
}

/**
 *  创建渲染缓冲区render buffer
 *  render buffer 是OpenGL的一个对象，用于存放渲染过的图像
 */
- (void)setupRenderBuffer {
    GLuint buffer;
    //调用函数来创建一个新的render buffer索引.这里返回一个唯一的integer来标记render buffer
    glGenRenderbuffers(1, &buffer);
    self.colorRenderBuffer = buffer;
    ///调用函数，告诉OpenGL，我们定义的buffer对象属于哪一种OpenGL对象
    glBindRenderbuffer(GL_RENDERBUFFER, self.colorRenderBuffer);
    // 为 color renderbuffer 分配存储空间
    [self.mContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.glLayer];
}

/**
 *  创建一个帧缓冲区frame buffer
 */
- (void)setupFrameBuffer {
    GLuint buffer;
    glGenFramebuffers(1, &buffer);
    self.colorFrameBuffer = buffer;
    // 设置为当前 framebuffer
    glBindFramebuffer(GL_FRAMEBUFFER, self.colorFrameBuffer);
    // 将 _colorRenderBuffer 装配到 GL_COLOR_ATTACHMENT0 这个装配点上
    // 把前面创建的buffer render 依附在frame buffer的GL_COLOR_ATTACHMENT0的位置
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER, self.colorRenderBuffer);
}

// Create a texture from an image
- (textureInfo_t)textureFromName:(NSString *)name {
    textureInfo_t texture;
    size_t width, height;
    GLuint texID;
    CGContextRef textureContex;
    GLubyte *data;
    CGImageRef imagedata = [UIImage imageNamed:name].CGImage;
    width = CGImageGetWidth(imagedata);
    height = CGImageGetHeight(imagedata);
    data = (GLubyte *)calloc(width * height * 4, sizeof(GLubyte));
    textureContex = CGBitmapContextCreate(data, width, height, 8, width * 4, CGImageGetColorSpace(imagedata), kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(textureContex, CGRectMake(0, 0, (CGFloat)width, (CGFloat)height), imagedata);
    CGContextRelease(textureContex);
    glGenTextures(1, &texID);
    glBindTexture(GL_TEXTURE_2D, texID);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)width, (int)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
    free(data);
    
    texture.id = texID;
    texture.width = (int)width;
    texture.height = (int)height;
    
    return texture;
}


- ( UIImage *)createShareImage:(NSString *)str
{
    
    UIImage *image = [ UIImage imageNamed : @"for_test.png" ];
    CGSize size= CGSizeMake (image. size . width , image. size . height ); // 画布大小
    UIGraphicsBeginImageContextWithOptions (size, NO , 0.0 );
    [image drawAtPoint : CGPointMake ( 0 , 0 )];
    
    // 获得一个位图图形上下文
    CGContextRef context= UIGraphicsGetCurrentContext ();
    CGContextDrawPath (context, kCGPathStroke );
    
    // 画文字
    [str drawAtPoint : CGPointMake (30 , image. size . height * 0.65 ) withAttributes : @{ NSFontAttributeName :[ UIFont fontWithName : @"Arial-BoldMT" size : 30 ], NSForegroundColorAttributeName :[ UIColor redColor ] } ];
    
    //画大圆并填充颜
    UIColor*aColor = [UIColor colorWithRed:1 green:0.0 blue:0 alpha:1];
    CGContextSetFillColorWithColor(context, aColor.CGColor);//填充颜色
    CGContextSetLineWidth(context, 3.0);//线的宽度
    CGContextAddArc(context, 250, 40, 40, 0, 2 * 3.14, 0); //添加一个圆
    //kCGPathFill填充非零绕数规则,kCGPathEOFill表示用奇偶规则,kCGPathStroke路径,kCGPathFillStroke路径填充,kCGPathEOFillStroke表示描线，不是填充
    CGContextDrawPath(context, kCGPathFillStroke); //绘制路径加填充
    
    // 返回绘制的新图形
    UIImage *newImage= UIGraphicsGetImageFromCurrentImageContext ();
    UIGraphicsEndImageContext ();
    return newImage;
}

/**
 *  获取图片里面的像素数据
 */
- (GLuint)setupTexture:(UIImage *)image {
    // 1获取图片的CGImageRef
    /**
     *  初始化一个UIImage对象，然后获得它的CGImage属性 图片规格有限制 只能用2次方的大小的图
     */
    CGImageRef spriteImage = image.CGImage;
    if (!spriteImage) {
        NSLog(@"Failed to load image %@", image);
        exit(1);
    }
    
    // 2 读取图片的大小
    /**
     *  获取image的宽度和高度然后手动分配空间 width*height*4个字节的数据空间
     *  空间*4的原因是，我们在调用方法来绘制图片数据时，我们要为red,green,blue和alpha通道，每个通道要准备一个字节
     *  每个通道准备一个字节的原因，因为要用CoreGraphics来建立绘图上下文。而CGBitmapContextCreate函数里面的第4个参数指定的就是每个通道要采用几位来表现，我们只用8位，所以是一个字节
     */
    size_t width = CGImageGetWidth(spriteImage);
    size_t height = CGImageGetHeight(spriteImage);
    
    GLubyte * spriteData = (GLubyte *) calloc(width * height * 4, sizeof(GLubyte)); //rgba共4个byte
    
    CGContextRef spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width*4,
                                                       CGImageGetColorSpace(spriteImage), kCGImageAlphaPremultipliedLast);
    
    // 3在CGContextRef上绘图
    // 告诉Core Graphics在一个指定的矩形区域内来绘制这些图像
    CGContextDrawImage(spriteContext, CGRectMake(0, 0, width, height), spriteImage);
    
    //完成绘制要释放
    CGContextRelease(spriteContext);
    
    // 4 绑定纹理到默认的纹理ID（这里只有一张图片，故而相当于默认于片元着色器里面的colorMap，如果有多张图不可以这么做）
    glBindTexture(GL_TEXTURE_2D, 0);
    /**
     *  多张图时，把像素信息发送给OpenGL,首先调用glGenTextures来创建一个纹理对象，并且得到一个唯一的ID，由"name"保存着。然后，我们调用glBindTexture来把我们新建的纹理名字加载到当前的纹理单元中。
     */
    /*
    GLuint texName;
    glGenTextures(1, &texName);
    glBindTexture(GL_TEXTURE_2D, texName);
    GLint textureUniform;
    glUniform1f(textureUniform, 0);
    */
    
    /**
     *  为我们的纹理设置纹理参数，使用glTexParameteri函数，。这里我们设置函数参数为GL_TEXTURE_MIN_FILTER（这个参数的意思是，当我们绘制远距离的对象的时候，我们会把纹理缩小）和GL_NEAREST(这个函数的意思是，当绘制顶点的时候，选择最临近的纹理像素)。
     */
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    float fw = width, fh = height;
    /**
     *  把像素中的数据发送给OpenGL，通过调用glTexImage2D.当你调用这个函数的时候，你需要指定像素格式。这里我们指定的是GL_RGBA和GL_UNSIGNED_BYTE.它的意思是，红绿蓝alpha道具都有，并且他们占用的空间是1个字节，也就是每个通道8位。
     */
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, fw, fh, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
    
    glBindTexture(GL_TEXTURE_2D, 0);
    
//     [self renderTarget];
    
    //已经把图片数据传送给了OpenGL,所以可以把这个释放掉
    free(spriteData);
    return 0;
}

@end
