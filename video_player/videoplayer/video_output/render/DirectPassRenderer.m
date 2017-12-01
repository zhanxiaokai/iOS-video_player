//
//  DirectPassRenderer.m
//  video_player
//
//  Created by apple on 16/9/1.
//  Copyright © 2016年 xiaokai.zhan. All rights reserved.
//

#import "DirectPassRenderer.h"

NSString *const kDirectPassVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 texcoord;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = texcoord;
 }
 );

NSString *const kDirectPassFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
 }
 );

@implementation DirectPassRenderer


- (BOOL) prepareRender:(NSInteger) frameWidth height:(NSInteger) frameHeight;
{
    BOOL ret = NO;
    if([self buildProgram:kDirectPassVertexShaderString fragmentShader:kDirectPassFragmentShaderString]) {
        glUseProgram(filterProgram);
        glEnableVertexAttribArray(filterPositionAttribute);
        glEnableVertexAttribArray(filterTextureCoordinateAttribute);
        ret = TRUE;
    }
    return ret;
}

- (void) renderWithWidth:(NSInteger) width height:(NSInteger) height position:(float)position
{
    glUseProgram(filterProgram);
    glViewport(0, 0, (int)width, (int)height);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _inputTexId);
    glUniform1i(filterInputTextureUniform, 0);
    
    static const GLfloat imageVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    GLfloat noRotationTextureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, imageVertices);
    glEnableVertexAttribArray(filterPositionAttribute);
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, noRotationTextureCoordinates);
    glEnableVertexAttribArray(filterTextureCoordinateAttribute);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

@end
