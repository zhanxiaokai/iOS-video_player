//
//  VideoOutput.h
//  video_player
//
//  Created by apple on 16/8/25.
//  Copyright © 2016年 xiaokai.zhan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "VideoDecoder.h"
#import "BaseEffectFilter.h"

@interface VideoOutput : UIView

- (id) initWithFrame:(CGRect)frame textureWidth:(NSInteger)textureWidth textureHeight:(NSInteger)textureHeight;
- (id) initWithFrame:(CGRect)frame textureWidth:(NSInteger)textureWidth textureHeight:(NSInteger)textureHeight  shareGroup:(EAGLSharegroup *)shareGroup;

- (void) presentVideoFrame:(VideoFrame*) frame;

- (BaseEffectFilter*) createImageProcessFilterInstance;
- (BaseEffectFilter*) getImageProcessFilterInstance;

- (void) destroy;

@end
